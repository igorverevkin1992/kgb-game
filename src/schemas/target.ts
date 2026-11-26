import { z } from 'zod';
import { Act, ClueId, FlagId, MiceAxis, Scale, TargetId, Text, Week } from './common';

/** Одна ось матрицы MICE у цели (GDD, Блок 2 и Схема 1). */
const MiceEntry = z.object({
  /** Истинное значение уязвимости. Игрок его не видит, пока ось не вскрыта уликами. */
  true_value: Scale,
  /** Конкретный рычаг, например `divorce_debt_65k`. null — рычага нет. */
  trigger: FlagId.nullable(),
  /** Вероятность обратного эффекта при давлении на эту ось (у компромата Кроноса 0.85). */
  backfire_risk: z.number().min(0).max(1).optional(),
});

/** Профиль объекта пирамиды вербовки. Один файл — одна цель: `src/content/targets/*.json`. */
export const Target = z.object({
  target_id: TargetId,
  /** Псевдоним в Центре (у Колдуэлла — «КРОНОС»). Появляется после вербовки. */
  codename_kgb: z.string().optional(),
  /** Эшелон пирамиды: 1 — периферия, 2 — силовой и внутренний контур, 3 — главная цель. */
  tier: z.union([z.literal(1), z.literal(2), z.literal(3)]),
  /** Акт, в котором цель появляется в игре. */
  act: Act,
  name: Text,
  role: Text,
  affiliation: z.string().min(1),
  access_tags: z.array(z.string()).default([]),

  /** Как цель открывается на доске: нужно собрать `clues_required` улик из списка `clue_ids`. */
  unlock: z.object({
    clues_required: z.number().int().min(1),
    clue_ids: z.array(ClueId).min(1),
  }),

  mice_profile: z.object({
    money: MiceEntry,
    ideology: MiceEntry,
    compromise: MiceEntry,
    ego: MiceEntry,
  }),

  approach: z.object({
    /** Под каким флагом вербуем: чужой, свой или бесконтактно. */
    flag_mode: z.enum(['false_flag', 'true_flag', 'contactless', 'indirect']),
    /** Легенда подхода, например «частный аудитор / кредитный брокер». */
    cover: Text,
    /** Ведущие оси MICE, без вскрытия которых вербовка невозможна. */
    key_axes: z.array(MiceAxis).min(1),
  }),

  /** Стартовое оперативное состояние (Схема 1, `operational_state`). */
  initial_state: z.object({
    rapport: Scale,
    paranoia: Scale,
    lifestyle_spending_index: Scale.default(0),
    cover_story_strength: Scale.default(0),
    polygraph_scheduled_week: Week.optional(),
  }),
});
export type Target = z.infer<typeof Target>;
