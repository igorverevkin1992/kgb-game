import { z } from 'zod';
import { Act, FlagId, OpId, TargetId, Text, Week } from './common';

/** Остановка проверочного маршрута: бытовая точка с легендой визита и замеченными приметами. */
const Waypoint = z.object({
  stop: z.string().min(1),
  name: Text,
  /** Зачем резидент сюда заехал (банк, химчистка, продукты). */
  cover_reason: z.string().min(1),
  /** Приметы, которые игрок видит на этой остановке, например `blue_ford_ltd`. */
  spotted_tags: z.array(z.string()).default([]),
});

/**
 * Полевая операция на карте SDR (GDD, Схема 2 `dead_drop_op.json`).
 * Один файл — одна операция: `src/content/ops/*.json`.
 */
export const Op = z.object({
  op_id: OpId,
  act: Act,
  week: Week,
  type: z.enum(['recon', 'dead_drop_load', 'dead_drop_clear', 'signal_check', 'personal_meeting']),
  title: Text,
  operative_id: z.enum(['op_resident_player', 'op_technician', 'op_diplomat']).default('op_resident_player'),
  /** Операция доступна только после открытия этих целей на доске. */
  requires_targets_unlocked: z.array(TargetId).default([]),
  location: z.object({
    site_id: z.string().min(1),
    name: Text,
    codename: z.string().optional(),
    within_25_mile_zone: z.boolean(),
    signal_site: z.string().optional(),
    signal_type: z.string().optional(),
    container_type: z.string().optional(),
  }),
  sdr_route: z.object({
    /** Классический SDR — ровно три бытовые точки. */
    waypoints: z.array(Waypoint).length(3, 'В маршруте SDR должно быть ровно 3 точки'),
    surveillance_present: z.boolean(),
    /** Примета, повторяющаяся на двух точках: «один раз — совпадение, дважды — работа противника». */
    repeating_cue: z.string().nullable(),
    abort_penalty_days: z.number().int().min(0).default(2),
    ignore_consequence: z
      .object({
        sog_heat_delta: z.number().int().min(0).max(100),
        flag_set: FlagId.optional(),
      })
      .optional(),
  }),
  payload: z
    .object({
      cash_usd: z.number().int().min(0).default(0),
      diamonds_usd: z.number().int().min(0).default(0),
      escrow_moscow_usd: z.number().int().min(0).default(0),
      ctr_4789_trigger_if_deposited_lump: z.boolean().default(false),
      mlca_1986_structuring_risk: z.number().min(0).max(1).default(0),
    })
    .optional(),
});
export type Op = z.infer<typeof Op>;
