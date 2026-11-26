import { z } from 'zod';
import { Act, FlagId, OpId, TargetId, Text, Week } from './common';
import { SiteId } from './map';

/**
 * Полевая операция на карте SDR (GDD, Схема 2 `dead_drop_op.json`).
 * Один файл — одна операция: `src/content/ops/*.json`.
 * Маршрут из трёх бытовых точек прокладывает сам игрок на карте; операция задаёт
 * только цель, наличие хвоста и последствия.
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
    /** Точка из `map/sites.json` с ролью `target`. */
    site_id: SiteId,
    codename: z.string().optional(),
    signal_site: z.string().optional(),
    signal_type: z.string().optional(),
    container_type: z.string().optional(),
  }),
  sdr: z.object({
    /** Есть ли за резидентом хвост SOG на этом выходе (при повторном выходе после отказа — нет). */
    surveillance_present: z.boolean(),
    /** Примета хвоста (`kind: "tail"` в `map/cues.json`): «один раз — совпадение, дважды — работа противника». */
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
