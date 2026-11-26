import { POLYGRAPH_VARS, type ClueSource, type Text } from '../../schemas';
import { withinZone } from '../map';
import { simulate } from './simulate';
import type { ContentBundle, Issue } from './types';

/** Лимиты длины документа (GDD, риск №2): до 120 слов — норма, больше 150 — ошибка. */
export const WORDS_WARN = 120;
export const WORDS_MAX = 150;

/** Сколько улик нужно, чтобы вывод считался подтверждённым («Правило трёх улик»). */
export const THREE_CLUES = 3;

const sourceKey = (s: ClueSource) => `${s.channel}:${s.from}`;

const CHANNEL_RU: Record<ClueSource['channel'], string> = {
  agent: 'агент',
  document: 'документ',
  field: 'полевая разведка',
};
const AXIS_RU = { money: 'Money', ideology: 'Ideology', compromise: 'Compromise', ego: 'Ego' } as const;

export const describeSource = (s: ClueSource) => `${CHANNEL_RU[s.channel]} ${s.from}`;

export function countWords(text: string): number {
  return text.split(/\s+/).filter(Boolean).length;
}

type Ctx = { content: ContentBundle; fileOf: Map<string, string>; issues: Issue[] };

function push(ctx: Ctx, issue: Omit<Issue, 'file'> & { id?: string; file?: string }) {
  const { id, ...rest } = issue;
  ctx.issues.push({ ...rest, file: rest.file ?? (id ? ctx.fileOf.get(id) : undefined) });
}

/** 1. Все ссылки ведут на существующие сущности. */
function checkReferences(ctx: Ctx) {
  const { content } = ctx;
  const targetIds = new Set(content.targets.map((t) => t.target_id));
  const clueIds = new Set(content.clues.map((c) => c.clue_id));
  const cableIds = new Set(content.cables.map((c) => c.cable_id));
  const opIds = new Set(content.ops.map((o) => o.op_id));
  const existsFor = { agent: targetIds, document: cableIds, field: opIds } as const;
  const kindRu = { agent: 'цели', document: 'депеши', field: 'операции' } as const;

  for (const clue of content.clues) {
    const { channel, from } = clue.source;
    if (!existsFor[channel].has(from)) {
      push(ctx, {
        level: 'error',
        rule: 'refs',
        id: clue.clue_id,
        where: `${clue.clue_id}.source.from`,
        message: `Улика ссылается на несуществующий источник: нет ${kindRu[channel]} «${from}»`,
      });
    }
    clue.reveals.forEach((r, i) => {
      if (!targetIds.has(r.target_id)) {
        push(ctx, {
          level: 'error',
          rule: 'refs',
          id: clue.clue_id,
          where: `${clue.clue_id}.reveals[${i}]`,
          message: `Улика вскрывает ось MICE у несуществующей цели «${r.target_id}»`,
        });
      }
    });
    if (clue.source.channel === 'agent' && clue.reveals.some((r) => r.target_id === clue.source.from)) {
      push(ctx, {
        level: 'warning',
        rule: 'refs',
        id: clue.clue_id,
        where: clue.clue_id,
        message: 'Агент доносит сам на себя: улика от агента вскрывает его же MICE',
      });
    }
  }

  for (const t of content.targets) {
    t.unlock.clue_ids.forEach((id, i) => {
      if (!clueIds.has(id)) {
        push(ctx, {
          level: 'error',
          rule: 'refs',
          id: t.target_id,
          where: `unlock.clue_ids[${i}]`,
          message: `Нет улики «${id}», а цель «${t.target_id}» открывается через неё`,
        });
      }
    });
  }

  for (const op of content.ops) {
    for (const id of op.requires_targets_unlocked) {
      if (!targetIds.has(id)) {
        push(ctx, {
          level: 'error',
          rule: 'refs',
          id: op.op_id,
          where: 'requires_targets_unlocked',
          message: `Операция требует открытую цель «${id}», но такой цели нет`,
        });
      }
    }
  }

  content.campaign.acts.forEach((a, i) => {
    for (const id of a.goal.recruit_any_of) {
      if (!targetIds.has(id)) {
        push(ctx, {
          level: 'error',
          rule: 'refs',
          file: 'campaign.json',
          where: `acts[${i}].goal.recruit_any_of`,
          message: `Цель акта ${a.act} — несуществующая цель «${id}»`,
        });
      }
    }
  });
}

/** 2. Открытие цели выполнимо и защищено «Правилом трёх улик». */
function checkUnlock(ctx: Ctx) {
  const clueById = new Map(ctx.content.clues.map((c) => [c.clue_id, c]));
  for (const t of ctx.content.targets) {
    const { clue_ids, clues_required } = t.unlock;
    if (new Set(clue_ids).size !== clue_ids.length) {
      push(ctx, { level: 'error', rule: 'unlock', id: t.target_id, where: 'unlock.clue_ids', message: 'В списке улик есть повторы' });
    }
    if (clue_ids.length < clues_required) {
      push(ctx, {
        level: 'error',
        rule: 'unlock',
        id: t.target_id,
        where: 'unlock',
        message: `Нужно ${clues_required} улик(и), а в списке всего ${clue_ids.length}: цель невозможно открыть`,
      });
      continue;
    }

    const known = clue_ids.map((id) => clueById.get(id)).filter((c) => c !== undefined);
    const sources = new Set(known.map((c) => sourceKey(c.source)));
    if (sources.size < THREE_CLUES) {
      push(ctx, {
        level: 'error',
        rule: 'three-clue',
        id: t.target_id,
        where: 'unlock.clue_ids',
        message: `«Правило трёх улик»: к цели ведут улики только из ${sources.size} независимых источников, нужно минимум ${THREE_CLUES}`,
      });
      continue;
    }
    // Если любой один источник сорвётся, оставшихся улик всё равно должно хватить.
    for (const key of sources) {
      const left = known.filter((c) => sourceKey(c.source) !== key).length;
      if (left < clues_required) {
        const [channel, from] = key.split(':') as [ClueSource['channel'], string];
        push(ctx, {
          level: 'error',
          rule: 'three-clue',
          id: t.target_id,
          where: 'unlock.clue_ids',
          message: `«Правило трёх улик»: если сорвётся источник «${describeSource({ channel, from } as ClueSource)}», останется ${left} улик(и) из ${clues_required} нужных — тупик`,
        });
      }
    }
  }
}

/** 3. Ведущие оси MICE вскрываются минимум тремя уликами. */
function checkKeyAxes(ctx: Ctx) {
  for (const t of ctx.content.targets) {
    for (const axis of t.approach.key_axes) {
      if (t.mice_profile[axis].trigger === null) {
        push(ctx, {
          level: 'warning',
          rule: 'mice-three-clue',
          id: t.target_id,
          where: `mice_profile.${axis}.trigger`,
          message: `Ось ${AXIS_RU[axis]} указана ведущей, но у неё нет рычага (trigger: null)`,
        });
      }
      const revealing = ctx.content.clues.filter((c) => c.reveals.some((r) => r.target_id === t.target_id && r.axis === axis));
      if (revealing.length < THREE_CLUES) {
        push(ctx, {
          level: 'error',
          rule: 'mice-three-clue',
          id: t.target_id,
          where: `approach.key_axes`,
          message: `«Правило трёх улик»: ведущую ось ${AXIS_RU[axis]} вскрывают ${revealing.length} улик(и), нужно минимум ${THREE_CLUES}`,
        });
      }
    }
  }
}

/** 4. Цель каждого акта достижима, и не ломается, если сорвётся любая одна ветка. */
function checkReachability(ctx: Ctx) {
  const { content } = ctx;
  for (const [i, act] of content.campaign.acts.entries()) {
    const goal = act.goal.recruit_any_of;
    const where = `acts[${i}].goal`;
    const full = simulate(content, { maxAct: act.act });
    if (!goal.some((id) => full.recruitedTargets.has(id))) {
      push(ctx, {
        level: 'error',
        rule: 'softlock',
        file: 'campaign.json',
        where,
        message: `Софтлок: цель акта ${act.act} (${goal.join(' или ')}) недостижима даже при идеальной игре`,
      });
      continue;
    }

    const failures: { label: string; targets?: string[]; ops?: string[] }[] = [
      ...content.targets
        .filter((t) => t.act <= act.act && !(goal.length === 1 && goal[0] === t.target_id))
        .map((t) => ({ label: `не удастся завербовать «${t.target_id}»`, targets: [t.target_id] })),
      ...content.ops
        .filter((o) => o.act <= act.act)
        .map((o) => ({ label: `сорвётся операция «${o.op_id}»`, ops: [o.op_id] })),
    ];
    for (const f of failures) {
      const res = simulate(content, {
        maxAct: act.act,
        failedTargets: new Set(f.targets),
        failedOps: new Set(f.ops),
      });
      if (!goal.some((id) => !f.targets?.includes(id) && res.recruitedTargets.has(id))) {
        push(ctx, {
          level: 'error',
          rule: 'robustness',
          file: 'campaign.json',
          where,
          message: `Тупик: если ${f.label}, цель акта ${act.act} становится недостижимой`,
        });
      }
    }
  }

  const all = simulate(content);
  for (const c of content.clues) {
    if (!all.clues.has(c.clue_id)) {
      push(ctx, {
        level: 'warning',
        rule: 'unreachable',
        id: c.clue_id,
        where: c.clue_id,
        message: `Улику «${c.clue_id}» невозможно получить ни при каком прохождении (источник ${describeSource(c.source)} недоступен)`,
      });
    }
  }
}

/**
 * 5. Карта и SDR честны: «один раз — совпадение, дважды — работа противника».
 * Карточки наблюдений собирает движок из примет, поэтому здесь проверяем, что приметы
 * не могут совпасть случайно и что у игрока есть из чего построить хороший маршрут.
 */
function checkMapAndSdr(ctx: Ctx) {
  const { content } = ctx;
  const sites = new Map(content.map.sites.map((s) => [s.site_id, s]));
  const cues = new Map(content.cues.map((c) => [c.tag, c]));
  const MAP = 'map/sites.json';
  const CUES = 'map/cues.json';

  const embassy = sites.get(content.balance.sdr.embassy_site);
  if (!embassy) {
    push(ctx, { level: 'error', rule: 'sdr', file: 'balance.json', where: 'sdr.embassy_site', message: `Нет точки посольства «${content.balance.sdr.embassy_site}» в ${MAP}` });
  }

  const seenAmbient = new Map<string, string>();
  for (const site of content.map.sites) {
    if (!content.map.districts[site.district]) {
      push(ctx, { level: 'error', rule: 'sdr', file: MAP, where: `${site.site_id}.district`, message: `Район «${site.district}» не описан в districts` });
    }
    if (site.role !== 'stop') continue;
    if (!site.cover_reason) {
      push(ctx, { level: 'error', rule: 'sdr', file: MAP, where: site.site_id, message: 'У бытовой точки маршрута нет легенды визита (cover_reason)' });
    }
    if (site.ambient_tags.length === 0) {
      push(ctx, { level: 'error', rule: 'sdr', file: MAP, where: `${site.site_id}.ambient_tags`, message: 'У точки маршрута нет местных примет' });
    }
    for (const tag of site.ambient_tags) {
      const cue = cues.get(tag);
      if (!cue) {
        push(ctx, { level: 'error', rule: 'refs', file: MAP, where: `${site.site_id}.ambient_tags`, message: `Нет приметы «${tag}» в ${CUES}` });
      } else if (cue.kind !== 'ambient') {
        push(ctx, { level: 'error', rule: 'sdr', file: MAP, where: `${site.site_id}.ambient_tags`, message: `Примета «${tag}» — не местная (kind: ${cue.kind}), её нельзя привязать к точке` });
      }
      const other = seenAmbient.get(tag);
      if (other) {
        push(ctx, {
          level: 'error',
          rule: 'sdr',
          file: MAP,
          where: `${site.site_id}.ambient_tags`,
          message: `Примета «${tag}» есть и у точки «${other}»: на маршруте через обе она повторится — ложный сигнал хвоста`,
        });
      }
      seenAmbient.set(tag, site.site_id);
    }
  }

  // Разные приметы с одинаковым текстом игрок примет за повтор — ложный сигнал хвоста.
  const byText = new Map<string, string>();
  for (const cue of content.cues) {
    const key = cue.text.ru.trim().toLowerCase();
    const other = byText.get(key);
    if (other) {
      push(ctx, { level: 'error', rule: 'sdr', file: CUES, where: cue.tag, message: `Текст приметы совпадает с «${other}» — игрок увидит ложный повтор` });
    }
    byText.set(key, cue.tag);
  }

  const noise = content.cues.filter((c) => c.kind === 'noise').length;
  if (noise < 3) {
    push(ctx, { level: 'error', rule: 'sdr', file: CUES, message: `Нужно минимум 3 приметы-«шума» (kind: noise), чтобы они не повторялись на трёх точках; сейчас ${noise}` });
  }

  // У игрока должен быть хотя бы один «правильный» маршрут: 3 точки в разных районах внутри зоны.
  const goodDistricts = new Set(
    content.map.sites.filter((s) => s.role === 'stop' && (!embassy || withinZone(content, s))).map((s) => s.district),
  );
  if (goodDistricts.size < content.balance.sdr.min_districts_for_double_sighting) {
    push(ctx, {
      level: 'error',
      rule: 'sdr',
      file: MAP,
      message: `Бытовые точки внутри 25-мильной зоны есть только в ${goodDistricts.size} районах — правильный маршрут SDR построить нельзя`,
    });
  }

  for (const op of content.ops) {
    const site = sites.get(op.location.site_id);
    if (!site) {
      push(ctx, { level: 'error', rule: 'refs', id: op.op_id, where: 'location.site_id', message: `Нет точки «${op.location.site_id}» в ${MAP}` });
    } else if (site.role !== 'target') {
      push(ctx, { level: 'error', rule: 'sdr', id: op.op_id, where: 'location.site_id', message: `Точка «${site.site_id}» не является целью операции (role: ${site.role})` });
    } else if (embassy && !withinZone(content, site)) {
      push(ctx, { level: 'warning', rule: 'sdr', id: op.op_id, where: 'location.site_id', message: 'Цель вне 25-мильной зоны: выезд потребует согласования с Госдепом' });
    }

    const { surveillance_present, repeating_cue } = op.sdr;
    if (surveillance_present) {
      if (!repeating_cue) {
        push(ctx, { level: 'error', rule: 'sdr', id: op.op_id, where: 'sdr.repeating_cue', message: 'Хвост есть, но не указана его примета' });
      } else if (cues.get(repeating_cue)?.kind !== 'tail') {
        push(ctx, {
          level: 'error',
          rule: 'sdr',
          id: op.op_id,
          where: 'sdr.repeating_cue',
          message: `Примета хвоста «${repeating_cue}» должна быть в ${CUES} с kind: "tail"`,
        });
      }
      if (!op.sdr.ignore_consequence) {
        push(ctx, { level: 'warning', rule: 'sdr', id: op.op_id, where: 'sdr.ignore_consequence', message: 'Хвост есть, но не задано последствие, если игрок его пропустит' });
      }
    } else if (repeating_cue) {
      push(ctx, { level: 'error', rule: 'sdr', id: op.op_id, where: 'sdr.repeating_cue', message: 'Хвоста нет, но указана его примета' });
    }
  }
}

/** 6. Недели депеш и операций попадают в рамки своего акта. */
function checkWeeks(ctx: Ctx) {
  const range = new Map(ctx.content.campaign.acts.map((a) => [a.act, a.weeks]));
  ctx.content.campaign.acts.forEach((a, i) => {
    if (a.weeks.from > a.weeks.to) {
      push(ctx, { level: 'error', rule: 'weeks', file: 'campaign.json', where: `acts[${i}].weeks`, message: 'Неделя начала акта позже недели конца' });
    }
  });
  const items = [
    ...ctx.content.cables.map((c) => ({ id: c.cable_id, act: c.act, week: c.week })),
    ...ctx.content.ops.map((o) => ({ id: o.op_id, act: o.act, week: o.week })),
  ];
  for (const it of items) {
    const r = range.get(it.act);
    if (!r) continue; // акт ещё не описан в campaign.json — не придираемся
    if (it.week < r.from || it.week > r.to) {
      push(ctx, {
        level: 'error',
        rule: 'weeks',
        id: it.id,
        where: `${it.id}.week`,
        message: `Неделя ${it.week} вне акта ${it.act} (недели ${r.from}–${r.to})`,
      });
    }
  }
}

/** 7. Длина документов и наличие перевода. */
function checkTexts(ctx: Ctx) {
  const long: { id: string; where: string; text: Text }[] = [
    ...ctx.content.clues.map((c) => ({ id: c.clue_id, where: `${c.clue_id}.text`, text: c.text })),
    ...ctx.content.cables.map((c) => ({ id: c.cable_id, where: `${c.cable_id}.body`, text: c.body })),
  ];
  for (const item of long) {
    for (const lang of ['ru', 'en'] as const) {
      const s = item.text[lang];
      if (!s) continue;
      const n = countWords(s);
      if (n > WORDS_MAX) {
        push(ctx, { level: 'error', rule: 'text-length', id: item.id, where: `${item.where}.${lang}`, message: `${n} слов — больше лимита ${WORDS_MAX}. Сократите документ` });
      } else if (n > WORDS_WARN) {
        push(ctx, { level: 'warning', rule: 'text-length', id: item.id, where: `${item.where}.${lang}`, message: `${n} слов — длиннее рекомендуемых ${WORDS_WARN}` });
      }
    }
  }

  let total = 0;
  let missing = 0;
  const walk = (v: unknown) => {
    if (Array.isArray(v)) v.forEach(walk);
    else if (v && typeof v === 'object') {
      const o = v as Record<string, unknown>;
      if (typeof o.ru === 'string') {
        total++;
        if (typeof o.en !== 'string' || o.en.trim() === '') missing++;
        return;
      }
      Object.values(o).forEach(walk);
    }
  };
  walk(ctx.content);
  if (missing > 0) {
    push(ctx, { level: 'warning', rule: 'translation', message: `Без английского перевода: ${missing} из ${total} текстов` });
  }
}

/** 8. Экзамены на полиграфе: категории вопросов и формулы. */
function checkPolygraph(ctx: Ctx) {
  const allowed = new Set<string>([...POLYGRAPH_VARS, 'AND', 'OR']);
  for (const exam of ctx.content.polygraph) {
    exam.question_sequence.forEach((q, i) => {
      const where = `question_sequence[${i}]`;
      if (q.category === 'relevant_critical' && !q.pass_formula) {
        push(ctx, { level: 'error', rule: 'polygraph', id: exam.exam_id, where, message: `Значимый вопрос «${q.q_id}» без условия прохождения pass_formula` });
      }
      if (q.category === 'control_comparison' && q.choices.length < 2) {
        push(ctx, { level: 'error', rule: 'polygraph', id: exam.exam_id, where, message: `У контрольного вопроса «${q.q_id}» должно быть минимум 2 варианта ответа` });
      }
      if (q.pass_formula) {
        const bad = (q.pass_formula.match(/[A-Za-z_]+/g) ?? []).filter((w) => !allowed.has(w));
        const junk = q.pass_formula.replace(/[A-Za-z_]+|\d+|>=|<=|==|[<>+\-()\s]/g, '');
        if (bad.length || junk) {
          push(ctx, {
            level: 'error',
            rule: 'polygraph',
            id: exam.exam_id,
            where: `${where}.pass_formula`,
            message: `Непонятная формула: ${[...bad, junk].filter(Boolean).join(', ')}. Допустимо: ${[...allowed].join(', ')}, числа, >= <= == < > + - ( )`,
          });
        }
      }
    });
  }
}

/** 9. Пороги сигналов баланса идут по возрастанию. */
function checkBalance(ctx: Ctx) {
  const { warning, danger } = ctx.content.balance.thresholds;
  if (warning >= danger) {
    push(ctx, { level: 'error', rule: 'balance', file: 'balance.json', where: 'thresholds', message: `Порог «warning» (${warning}) должен быть меньше порога «danger» (${danger})` });
  }
}

export function checkRules(content: ContentBundle, fileOf: Map<string, string>): Issue[] {
  const ctx: Ctx = { content, fileOf, issues: [] };
  checkReferences(ctx);
  checkUnlock(ctx);
  checkKeyAxes(ctx);
  checkReachability(ctx);
  checkMapAndSdr(ctx);
  checkWeeks(ctx);
  checkTexts(ctx);
  checkPolygraph(ctx);
  checkBalance(ctx);
  return ctx.issues;
}
