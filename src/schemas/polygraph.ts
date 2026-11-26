import { z } from 'zod';
import { ExamId, Scale, Text } from './common';

/** Переменные, которые можно использовать в `pass_formula`. */
export const POLYGRAPH_VARS = ['control_peak', 'relevant_peak', 'rapport', 'skepticism'] as const;

const Effects = z.object({
  rapport: z.number().int().optional(),
  skepticism: z.number().int().optional(),
  control_peak: z.number().int().optional(),
  relevant_peak: z.number().int().optional(),
});

const Choice = z.object({
  choice_id: z.string().regex(/^[a-z0-9_]+$/),
  label: Text,
  effects: Effects,
});

const Question = z.object({
  q_id: z.string().regex(/^q_[a-z0-9_]+$/, 'q_id должен начинаться с «q_»'),
  /** Метод контрольных вопросов (CQT): нейтральные, контрольные и значимые вопросы. */
  category: z.enum(['neutral', 'control_comparison', 'relevant_critical']),
  text: Text,
  choices: z.array(Choice).default([]),
  /** Условие прохождения значимого вопроса, например `control_peak >= relevant_peak - 5 AND rapport >= 65`. */
  pass_formula: z.string().optional(),
});

/** Экзамен на полиграфе ЦРУ (GDD, Схема 3). Один файл — один экзамен: `src/content/polygraph/*.json`. */
export const PolygraphExam = z.object({
  exam_id: ExamId,
  examiner_profile: z.object({
    name: Text,
    archetype: z.enum(['chummy_veteran', 'rigid_formalist']),
    rapport_threshold_pass: Scale,
    skepticism_fail_limit: Scale,
  }),
  pre_test_modifiers: z.record(
    z.string(),
    z.object({
      baseline_stability: z.number().int().optional(),
      chart_authenticity: z.number().int().optional(),
      finance_question_stress: z.number().int().optional(),
      required_prep_id: z.string().optional(),
      condition: z.string().optional(),
    }),
  ),
  question_sequence: z.array(Question).min(1),
});
export type PolygraphExam = z.infer<typeof PolygraphExam>;
