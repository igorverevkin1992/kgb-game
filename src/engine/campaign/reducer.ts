import type { MiceAxis, Op, Site } from '../../schemas';
import type { ContentBundle } from '../content';
import { analyzeRoute, siteById, withinZone } from '../map';
import { nextRandom } from '../rng';
import { availableOps, currentActDef, nextActDef, tailPresent } from './selectors';
import {
  initialTargetState,
  type CampaignState,
  type Ending,
  type GameEvent,
  type Phase,
  type Report,
  type Risk,
} from './state';

/** Действия игрока. Каждое приходит из модуля рабочего стола. */
export type Action =
  /** Перейти к следующей фазе недели (ночью вместо этого отправляют донесение). */
  | { type: 'advance_phase' }
  /** Отметить документ из утренней почты прочитанным. */
  | { type: 'read_cable'; cable_id: string }
  /** День: запланировать полевую операцию по маршруту SDR из трёх бытовых точек (или отменить). */
  | { type: 'plan_op'; op_id: string; route: string[] }
  | { type: 'cancel_op'; op_id: string }
  /** Вечер: итог маршрута SDR — продолжить операцию или свернуть на бытовую легенду. */
  | { type: 'resolve_op'; op_id: string; decision: 'continue' | 'abort' }
  /** Вечер: итог вербовочной беседы. */
  | { type: 'recruitment'; target_id: string; result: 'success' | 'failed' | 'postponed' }
  /** Ночь: что доложить в Центр. Завершает неделю. */
  | { type: 'submit_report'; report: Report };

export interface StepResult {
  state: CampaignState;
  events: GameEvent[];
  /** Почему действие отклонено (состояние тогда не меняется). */
  error?: string;
}

const NEXT_PHASE: Record<Phase, Phase | null> = { morning: 'day', day: 'evening', evening: 'night', night: null };
const clamp = (v: number) => Math.max(0, Math.min(100, v));

/** Изменяемая копия состояния на время одного действия + накопленные события. */
class Tx {
  readonly events: GameEvent[] = [];
  constructor(
    readonly s: CampaignState,
    readonly content: ContentBundle,
  ) {}

  emit(event: GameEvent) {
    this.events.push(event);
    this.s.log.push({ week: this.s.week, phase: this.s.phase, event });
  }

  setPhase(phase: Phase) {
    this.s.phase = phase;
    this.emit({ type: 'phase_changed', phase });
  }

  setFlag(flag: string) {
    if (this.s.flags.includes(flag)) return;
    this.s.flags.push(flag);
    this.emit({ type: 'flag_set', flag });
  }

  addRisk(risk: Risk, delta: number, reason: string) {
    if (delta === 0) return;
    let d = delta;
    if (risk === 'mole_hunt' && d > 0 && this.s.flags.includes('treasury_audit')) {
      d = Math.round(d * this.content.balance.treasury.audit_mole_hunt_multiplier);
    }
    const from = this.s.risks[risk];
    const to = clamp(from + d);
    if (to === from) return;
    this.s.risks[risk] = to;
    this.emit({ type: 'risk_changed', risk, from, to, reason });
    if (risk === 'treasury' && to >= 100) this.setFlag('treasury_audit');
  }

  addTrust(delta: number, reason: string) {
    const from = this.s.centre_trust;
    const to = clamp(from + delta);
    if (to === from) return;
    this.s.centre_trust = to;
    this.emit({ type: 'trust_changed', from, to, reason });
  }

  roll(): number {
    const [value, next] = nextRandom(this.s.rng);
    this.s.rng = next;
    return value;
  }

  giveClue(clueId: string) {
    if (this.s.clues.includes(clueId)) return;
    const clue = this.content.clues.find((c) => c.clue_id === clueId);
    if (!clue) return;
    this.s.clues.push(clueId);
    this.emit({ type: 'clue_found', clue_id: clueId });

    for (const r of clue.reveals) this.discoverAxis(r.target_id, r.axis);
    for (const t of this.content.targets) {
      const ts = this.s.targets[t.target_id];
      if (!ts || ts.unlocked || !t.unlock.clue_ids.includes(clueId)) continue;
      const found = t.unlock.clue_ids.filter((id) => this.s.clues.includes(id)).length;
      if (found >= t.unlock.clues_required) {
        ts.unlocked = true;
        this.emit({ type: 'target_unlocked', target_id: t.target_id });
      }
    }
  }

  discoverAxis(targetId: string, axis: MiceAxis) {
    const ts = this.s.targets[targetId];
    if (!ts || ts.discovered_axes.includes(axis)) return;
    ts.discovered_axes.push(axis);
    this.emit({ type: 'axis_discovered', target_id: targetId, axis });
  }

  end(ending: Ending) {
    this.s.ending = ending;
    this.emit({ type: 'game_over', ending });
  }
}

/**
 * Карточки наблюдений для трёх точек маршрута SDR. На каждой точке — местная примета и
 * случайный прохожий («шум», без повторов). Если за резидентом хвост, его примета мелькает:
 * на маршруте через разные районы — дважды («дважды — работа противника»), а если точки
 * в одном-двух районах — один раз: бригада SOG меняет машины, и повтор не виден.
 */
function buildObservations(tx: Tx, op: Op, stops: Site[]): string[][] {
  const { content, s } = tx;
  const pick = <T,>(items: T[]): T | undefined => items[Math.floor(tx.roll() * items.length)];

  const noise = content.cues.filter((c) => c.kind === 'noise').map((c) => c.tag);
  for (let i = noise.length - 1; i > 0; i--) {
    const j = Math.floor(tx.roll() * (i + 1));
    [noise[i], noise[j]] = [noise[j]!, noise[i]!];
  }

  let tailStops: number[] = [];
  const tail = tailPresent(s, op) ? op.sdr.repeating_cue : null;
  if (tail) {
    const districts = new Set(stops.map((st) => st.district)).size;
    if (districts >= content.balance.sdr.min_districts_for_double_sighting) {
      const skip = Math.floor(tx.roll() * 3);
      tailStops = [0, 1, 2].filter((i) => i !== skip);
    } else {
      tailStops = [2];
    }
  }

  return stops.map((site, i) => {
    const cards: string[] = [];
    const ambient = pick(site.ambient_tags);
    if (ambient) cards.push(ambient);
    const n = noise[i];
    if (n) cards.push(n);
    if (tail && tailStops.includes(i)) cards.splice(Math.floor(tx.roll() * (cards.length + 1)), 0, tail);
    return cards;
  });
}

/** Утро: свежая почта, донесения агентов, обнуление недельных счётчиков. */
function startMorning(tx: Tx) {
  const { s, content } = tx;
  s.phase = 'morning';
  s.week_failures = 0;
  s.week_field_activity = false;
  tx.emit({ type: 'week_started', week: s.week, act: s.act });

  const fresh = content.cables.filter(
    (c) => c.act <= s.act && c.week <= s.week && !s.delivered_cables.includes(c.cable_id),
  );
  for (const cable of fresh) {
    s.delivered_cables.push(cable.cable_id);
    tx.emit({ type: 'cable_delivered', cable_id: cable.cable_id });
    for (const clue of content.clues) {
      if (clue.source.channel === 'document' && clue.source.from === cable.cable_id) tx.giveClue(clue.clue_id);
    }
  }

  // Каждый завербованный агент приносит по одному донесению в неделю.
  for (const t of content.targets) {
    const ts = s.targets[t.target_id];
    if (!ts?.recruited) continue;
    const reports = content.clues.filter((c) => c.source.channel === 'agent' && c.source.from === t.target_id);
    const next = reports[ts.reports_delivered];
    if (next) {
      ts.reports_delivered++;
      tx.giveClue(next.clue_id);
    }
  }
}

/** Новая кампания по числам из balance.json и структуре из campaign.json. */
export function newCampaign(content: ContentBundle): StepResult {
  const { balance, campaign } = content;
  const first = [...campaign.acts].sort((a, b) => a.act - b.act)[0];
  if (!first) throw new Error('В campaign.json нет актов');
  const state: CampaignState = {
    act: first.act,
    week: first.weeks.from,
    phase: 'morning',
    risks: { ...balance.start.risks },
    centre_trust: balance.start.centre_trust,
    fund_usd: balance.start.fund_usd,
    flags: [],
    delivered_cables: [],
    read_cables: [],
    clues: [],
    targets: Object.fromEntries(content.targets.map((t) => [t.target_id, initialTargetState(content, t.target_id)])),
    planned_ops: [],
    routes: {},
    op_results: {},
    site_visits: {},
    week_failures: 0,
    week_field_activity: false,
    lies: [],
    goal_reached: false,
    rng: balance.start.seed,
    ending: null,
    log: [],
  };
  const tx = new Tx(state, content);
  startMorning(tx);
  return { state, events: tx.events };
}

const reject = (state: CampaignState, error: string): StepResult => ({ state, events: [], error });

/** Названия мотивов для сообщений игроку (доска мотивов: Д/И/К/С). */
export const AXIS_NAME_RU: Record<MiceAxis, string> = {
  money: 'деньги',
  ideology: 'идеология',
  compromise: 'компромат',
  ego: 'самолюбие',
};

const opTitle = (content: ContentBundle, id: string) => content.ops.find((o) => o.op_id === id)?.title.ru ?? id;

/**
 * Главная функция движка: применяет действие игрока и возвращает новое состояние и события.
 * Исходное состояние не меняется. Неверное действие возвращает `error` по-русски.
 */
export function dispatch(state: CampaignState, content: ContentBundle, action: Action): StepResult {
  if (state.ending) return reject(state, 'Кампания окончена');
  const tx = new Tx(structuredClone(state), content);
  const { s } = tx;
  const phaseRu = { morning: 'утро', day: 'день', evening: 'вечер', night: 'ночь' }[s.phase];

  switch (action.type) {
    case 'advance_phase': {
      const next = NEXT_PHASE[s.phase];
      if (!next) return reject(state, 'Ночью неделя завершается донесением в Центр');
      if (s.phase === 'evening' && s.planned_ops.length) {
        return reject(state, `Не разыграны операции: ${s.planned_ops.map((id) => opTitle(content, id)).join(', ')}`);
      }
      tx.setPhase(next);
      break;
    }

    case 'read_cable': {
      if (!s.delivered_cables.includes(action.cable_id)) return reject(state, 'Этот документ ещё не поступал');
      if (!s.read_cables.includes(action.cable_id)) s.read_cables.push(action.cable_id);
      break;
    }

    case 'plan_op': {
      if (s.phase !== 'day') return reject(state, `Операции планируют днём, а сейчас ${phaseRu}`);
      if (!availableOps(s, content).some((o) => o.op_id === action.op_id)) {
        return reject(state, `Операция «${opTitle(content, action.op_id)}» сейчас недоступна`);
      }
      if (s.planned_ops.length >= content.balance.ops.per_week) {
        return reject(state, `На неделю можно запланировать не больше ${content.balance.ops.per_week} операций`);
      }
      const route = analyzeRoute(content, action.route);
      if (route.blocking.length) {
        return reject(state, 'Проверочный маршрут — это три разные бытовые точки на карте');
      }
      const op = content.ops.find((o) => o.op_id === action.op_id)!;
      const stops = action.route.map((id) => siteById(content, id)!);
      s.routes[op.op_id] = { stops: action.route, observations: buildObservations(tx, op, stops) };
      s.planned_ops.push(action.op_id);
      tx.emit({ type: 'op_planned', op_id: action.op_id });
      break;
    }

    case 'cancel_op': {
      if (s.phase !== 'day') return reject(state, 'Отменить операцию можно только днём');
      if (!s.planned_ops.includes(action.op_id)) return reject(state, 'Эта операция не запланирована');
      s.planned_ops = s.planned_ops.filter((id) => id !== action.op_id);
      delete s.routes[action.op_id];
      tx.emit({ type: 'op_cancelled', op_id: action.op_id });
      break;
    }

    case 'resolve_op': {
      if (s.phase !== 'evening') return reject(state, `Операции проводятся вечером, а сейчас ${phaseRu}`);
      if (!s.planned_ops.includes(action.op_id)) return reject(state, 'Эта операция не запланирована');
      const op = content.ops.find((o) => o.op_id === action.op_id)!;
      const b = content.balance.sog_heat;
      const tail = tailPresent(s, op);
      const routeStops = (s.routes[op.op_id]?.stops ?? []).map((id) => siteById(content, id)).filter((x) => x !== undefined);
      s.planned_ops = s.planned_ops.filter((id) => id !== op.op_id);
      delete s.routes[op.op_id];
      s.week_field_activity = true;

      // Каждая точка маршрута за 25 милями — заметный для ФБР выезд, даже если операцию свернули.
      for (const stop of routeStops) {
        if (!withinZone(content, stop)) tx.addRisk('sog_heat', b.outside_25_mile_zone, 'outside_25_miles');
      }

      if (action.decision === 'abort') {
        s.op_results[op.op_id] = 'aborted';
        s.week_failures++;
        tx.emit({ type: 'op_resolved', op_id: op.op_id, outcome: 'aborted' });
        break;
      }

      const site = op.location.site_id;
      const visits = s.site_visits[site] ?? 0;
      s.site_visits[site] = visits + 1;
      if (visits > 0) tx.addRisk('sog_heat', b.site_reuse_per_use * visits, 'site_reuse');
      const target = siteById(content, site);
      if (target && !withinZone(content, target)) tx.addRisk('sog_heat', b.outside_25_mile_zone, 'outside_25_miles');

      // Хвост был, а игрок продолжил: улики добыты, но ФБР всё зафиксировало (скрытый флаг).
      const outcome = tail ? 'tail_missed' : 'clean';
      if (outcome === 'tail_missed') {
        const c = op.sdr.ignore_consequence;
        tx.addRisk('sog_heat', c?.sog_heat_delta ?? b.missed_tail_default, 'missed_tail');
        if (c?.flag_set) tx.setFlag(c.flag_set);
      }
      s.op_results[op.op_id] = outcome;
      tx.emit({ type: 'op_resolved', op_id: op.op_id, outcome });
      for (const clue of content.clues) {
        if (clue.source.channel === 'field' && clue.source.from === op.op_id) tx.giveClue(clue.clue_id);
      }
      break;
    }

    case 'recruitment': {
      if (s.phase !== 'evening') return reject(state, `Вербовочные беседы проводятся вечером, а сейчас ${phaseRu}`);
      const target = content.targets.find((t) => t.target_id === action.target_id);
      const ts = s.targets[action.target_id];
      if (!target || !ts) return reject(state, 'Такой цели нет');
      if (ts.recruited || ts.lost) return reject(state, 'С этой целью работа уже закончена');
      if (!ts.unlocked) return reject(state, 'Цель ещё не установлена: не хватает улик');

      if (action.result === 'success') {
        const missing = target.approach.key_axes.filter((a) => !ts.discovered_axes.includes(a));
        if (missing.length) return reject(state, `Не вскрыты ведущие мотивы: ${missing.map((a) => AXIS_NAME_RU[a]).join(', ')}`);
        ts.recruited = true;
        tx.emit({ type: 'target_recruited', target_id: target.target_id });
        if (currentActDef(s, content)?.goal.recruit_any_of.includes(target.target_id)) s.goal_reached = true;
      } else if (action.result === 'failed') {
        ts.lost = true;
        s.week_failures++;
        tx.emit({ type: 'target_lost', target_id: target.target_id });
        tx.addRisk('sog_heat', content.balance.sog_heat.failed_recruitment, 'failed_recruitment');
      } else {
        tx.emit({ type: 'recruitment_postponed', target_id: target.target_id });
      }
      break;
    }

    case 'submit_report': {
      if (s.phase !== 'night') return reject(state, `Донесение в Центр отправляют ночью, а сейчас ${phaseRu}`);
      endWeek(tx, action.report);
      break;
    }
  }

  return { state: s, events: tx.events };
}

/** Ночь: донесение, сверка лжи, пересчёт рисков, концовки и переход к следующей неделе. */
function endWeek(tx: Tx, report: Report) {
  const { s, content } = tx;
  const { moscow_pressure: mp, centre_trust: ct, lies, sog_heat } = content.balance;
  const failures = s.week_failures > 0;

  tx.emit({ type: 'report_submitted', report });
  if (report === 'truth') {
    if (failures) {
      tx.addTrust(ct.report_truth_with_failures, 'report_truth_with_failures');
      tx.addRisk('moscow_pressure', mp.report_truth_with_failures, 'report_truth_with_failures');
    } else {
      tx.addTrust(ct.report_truth, 'report_truth');
    }
  } else if (report === 'embellished') {
    tx.addTrust(ct.report_embellished, 'report_embellished');
    tx.addRisk('moscow_pressure', mp.report_embellished, 'report_embellished');
    s.lies.push({ week: s.week, kind: 'embellished' });
  } else {
    tx.addTrust(ct.report_silence, 'report_silence');
    if (failures) s.lies.push({ week: s.week, kind: 'silence' });
  }

  // Сверка донесений: каждая ложь либо вскрывается, либо уходит в архив навсегда.
  if (s.week % lies.check_every_weeks === 0 && s.lies.length) {
    for (const lie of s.lies) {
      const chance = lie.kind === 'embellished' ? lies.uncover_chance_embellished : lies.uncover_chance_silence;
      if (tx.roll() < chance) {
        tx.emit({ type: 'lie_uncovered', lie_week: lie.week });
        tx.addTrust(ct.lie_uncovered, 'lie_uncovered');
        tx.addRisk('moscow_pressure', mp.lie_uncovered, 'lie_uncovered');
        tx.setFlag('centre_caught_lie');
      }
    }
    s.lies = [];
  }

  const act = currentActDef(s, content);
  if (s.goal_reached) {
    tx.addRisk('moscow_pressure', mp.act_goal_reached, 'act_goal_reached');
    tx.emit({ type: 'act_completed', act: s.act });
  } else if (act && s.week > act.weeks.to) {
    tx.addRisk('moscow_pressure', mp.per_week_overdue, 'act_overdue');
  } else if (act && s.week - act.weeks.from + 1 > mp.grace_weeks) {
    tx.addRisk('moscow_pressure', mp.per_week_without_goal, 'no_progress');
  }

  if (!s.week_field_activity) tx.addRisk('sog_heat', sog_heat.quiet_week, 'quiet_week');

  if (s.risks.sog_heat >= 100) return tx.end('persona_non_grata');
  if (s.risks.moscow_pressure >= 100) return tx.end('recalled');
  if (s.risks.mole_hunt >= 100) return tx.end('mole_arrested');

  if (s.goal_reached) {
    const next = nextActDef(s, content);
    if (!next) return tx.end('campaign_complete');
    s.act = next.act;
    s.week = Math.max(s.week + 1, next.weeks.from); // сюжетный скачок во времени между актами
    s.goal_reached = false;
  } else {
    s.week += 1;
    if (s.week > 30) return tx.end('recalled');
  }
  startMorning(tx);
}
