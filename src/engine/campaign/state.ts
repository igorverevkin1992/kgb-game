import { z } from 'zod';
import { MiceAxis } from '../../schemas';
import type { ContentBundle } from '../content';

/** Четыре фазы операционной недели (GDD, Блок 3 «Макро- и микроцикл»). */
export const PHASES = ['morning', 'day', 'evening', 'night'] as const;
export const Phase = z.enum(PHASES);
export type Phase = z.infer<typeof Phase>;

/** Четыре сообщающиеся шкалы риска (GDD, Блок 3 «Система рисков»). */
export const RISKS = ['sog_heat', 'mole_hunt', 'treasury', 'moscow_pressure'] as const;
export const Risk = z.enum(RISKS);
export type Risk = z.infer<typeof Risk>;

export const Report = z.enum(['truth', 'embellished', 'silence']);
export type Report = z.infer<typeof Report>;

export const OpOutcome = z.enum(['clean', 'tail_missed', 'aborted']);
export type OpOutcome = z.infer<typeof OpOutcome>;

export const Ending = z.enum([
  /** Наружка ФБР = 100: нота Госдепа, высылка резидента. */
  'persona_non_grata',
  /** Давление Центра = 100: отзыв резидента в Москву. */
  'recalled',
  /** Охота в Лэнгли = 100: круг сужен, «крот» арестован. */
  'mole_arrested',
  /** Пройден последний акт, описанный в campaign.json (пока — конец вертикального среза). */
  'campaign_complete',
]);
export type Ending = z.infer<typeof Ending>;

const Pct = z.number().min(0).max(100);

export const TargetState = z.object({
  unlocked: z.boolean(),
  recruited: z.boolean(),
  /** Вербовка провалилась: цель потеряна для игрока. */
  lost: z.boolean(),
  discovered_axes: z.array(MiceAxis),
  rapport: Pct,
  paranoia: Pct,
  /** Сколько донесений этого агента уже получено. */
  reports_delivered: z.number().int().min(0),
});
export type TargetState = z.infer<typeof TargetState>;

export const GameEvent = z.discriminatedUnion('type', [
  z.object({ type: z.literal('week_started'), week: z.number(), act: z.number() }),
  z.object({ type: z.literal('phase_changed'), phase: Phase }),
  z.object({ type: z.literal('cable_delivered'), cable_id: z.string() }),
  z.object({ type: z.literal('clue_found'), clue_id: z.string() }),
  z.object({ type: z.literal('axis_discovered'), target_id: z.string(), axis: MiceAxis }),
  z.object({ type: z.literal('target_unlocked'), target_id: z.string() }),
  z.object({ type: z.literal('op_planned'), op_id: z.string() }),
  z.object({ type: z.literal('op_cancelled'), op_id: z.string() }),
  z.object({ type: z.literal('op_resolved'), op_id: z.string(), outcome: OpOutcome }),
  z.object({ type: z.literal('target_recruited'), target_id: z.string() }),
  z.object({ type: z.literal('target_lost'), target_id: z.string() }),
  z.object({ type: z.literal('recruitment_postponed'), target_id: z.string() }),
  z.object({ type: z.literal('risk_changed'), risk: Risk, from: z.number(), to: z.number(), reason: z.string() }),
  z.object({ type: z.literal('trust_changed'), from: z.number(), to: z.number(), reason: z.string() }),
  z.object({ type: z.literal('report_submitted'), report: Report }),
  z.object({ type: z.literal('lie_uncovered'), lie_week: z.number() }),
  z.object({ type: z.literal('flag_set'), flag: z.string() }),
  z.object({ type: z.literal('act_completed'), act: z.number() }),
  z.object({ type: z.literal('game_over'), ending: Ending }),
]);
export type GameEvent = z.infer<typeof GameEvent>;

/** Полное состояние кампании. Только данные и id: его можно сохранить в JSON. */
export const CampaignState = z.object({
  act: z.union([z.literal(1), z.literal(2), z.literal(3), z.literal(4)]),
  week: z.number().int().min(1),
  phase: Phase,
  risks: z.object({ sog_heat: Pct, mole_hunt: Pct, treasury: Pct, moscow_pressure: Pct }),
  centre_trust: Pct,
  fund_usd: z.number().int(),
  flags: z.array(z.string()),

  delivered_cables: z.array(z.string()),
  read_cables: z.array(z.string()),
  clues: z.array(z.string()),
  targets: z.record(z.string(), TargetState),

  /** Операции, запланированные на эту неделю (фаза «День»), и ещё не разыгранные. */
  planned_ops: z.array(z.string()),
  /**
   * Утверждённые маршруты SDR запланированных операций: три точки и приметы, которые
   * резидент увидит на каждой (собираются при планировании, чтобы сохранение их помнило).
   */
  routes: z.record(z.string(), z.object({ stops: z.array(z.string()).length(3), observations: z.array(z.array(z.string())) })),
  /** Итоги разыгранных операций: op_id → результат (последний). */
  op_results: z.record(z.string(), OpOutcome),
  /** Сколько раз резидент выходил на каждую точку (повторы злят наружку). */
  site_visits: z.record(z.string(), z.number().int()),

  /** Сбои этой недели: о них решаем, докладывать ли в Центр. */
  week_failures: z.number().int().min(0),
  /** Были ли на этой неделе полевые выходы (для оперативной паузы). */
  week_field_activity: z.boolean(),
  /** Неразоблачённые неправдивые донесения: их проверят при ближайшей сверке. */
  lies: z.array(z.object({ week: z.number().int(), kind: z.enum(['embellished', 'silence']) })),
  goal_reached: z.boolean(),

  rng: z.number().int().min(0),
  ending: Ending.nullable(),
  /** Журнал событий: что произошло, на какой неделе и в какой фазе. */
  log: z.array(z.object({ week: z.number(), phase: Phase, event: GameEvent })),
});
export type CampaignState = z.infer<typeof CampaignState>;

export function initialTargetState(content: ContentBundle, targetId: string): TargetState {
  const t = content.targets.find((x) => x.target_id === targetId);
  if (!t) throw new Error(`Нет цели ${targetId}`);
  return {
    unlocked: false,
    recruited: false,
    lost: false,
    discovered_axes: [],
    rapport: t.initial_state.rapport,
    paranoia: t.initial_state.paranoia,
    reports_delivered: 0,
  };
}
