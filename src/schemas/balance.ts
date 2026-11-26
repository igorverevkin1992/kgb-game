import { z } from 'zod';
import { Scale } from './common';

const Delta = z.number().int().min(-100).max(100);
const Chance = z.number().min(0).max(1);

/**
 * Числа баланса кампании: `src/content/balance.json`.
 * Все шкалы 0–100, «дельты» — на сколько шкала меняется за событие.
 */
export const Balance = z.object({
  start: z.object({
    fund_usd: z.number().int().min(0),
    centre_trust: Scale,
    risks: z.object({ sog_heat: Scale, mole_hunt: Scale, treasury: Scale, moscow_pressure: Scale }),
    seed: z.number().int().min(0).default(1985),
  }),
  ops: z.object({
    /** Сколько операций резидент может запланировать на одну неделю. */
    per_week: z.number().int().min(1).max(5),
  }),
  sdr: z.object({
    /** Посольство — центр дипломатической зоны. */
    embassy_site: z.string(),
    /** Радиус свободного передвижения дипломатов, мили. */
    zone_radius_miles: z.number().positive(),
    /** Сколько разных районов нужно на маршруте, чтобы хвост мелькнул дважды. */
    min_districts_for_double_sighting: z.number().int().min(1).max(3),
  }),
  sog_heat: z.object({
    /** Если у операции не задано своё `ignore_consequence.sog_heat_delta`. */
    missed_tail_default: Delta,
    outside_25_mile_zone: Delta,
    /** Повторный выход на ту же точку: за каждое предыдущее посещение. */
    site_reuse_per_use: Delta,
    /** Оперативная пауза: неделя без полевых выходов. Обычно отрицательное число. */
    quiet_week: Delta,
    failed_recruitment: Delta,
  }),
  moscow_pressure: z.object({
    /** Сколько недель акта Центр ждёт результата спокойно. */
    grace_weeks: z.number().int().min(0),
    per_week_without_goal: Delta,
    per_week_overdue: Delta,
    act_goal_reached: Delta,
    report_truth_with_failures: Delta,
    report_embellished: Delta,
    lie_uncovered: Delta,
  }),
  centre_trust: z.object({
    report_truth: Delta,
    report_truth_with_failures: Delta,
    report_embellished: Delta,
    report_silence: Delta,
    lie_uncovered: Delta,
  }),
  lies: z.object({
    /** Раз в сколько недель Центр сверяет донесения. */
    check_every_weeks: z.number().int().min(1),
    uncover_chance_embellished: Chance,
    uncover_chance_silence: Chance,
  }),
  treasury: z.object({
    /** После финансового аудита (Treasury = 100) охота в Лэнгли ускоряется во столько раз. */
    audit_mole_hunt_multiplier: z.number().min(1).max(5),
  }),
  /** Уровни сигналов на столе: от «warning» — тревожно, от «danger» — опасно. */
  thresholds: z.object({ warning: Scale, danger: Scale }),
});
export type Balance = z.infer<typeof Balance>;
