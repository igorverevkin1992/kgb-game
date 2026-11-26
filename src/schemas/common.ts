import { z } from 'zod';

// Сообщения Zod на русском: валидатор контента читает пользователь, а не программист.
z.config(z.locales.ru());

/**
 * Двуязычный текст. Русский обязателен. Английский можно дописать позже:
 * валидатор напомнит предупреждением, сколько текстов ещё без перевода.
 */
export const Text = z.object({
  ru: z.string().min(1, 'Русский текст не может быть пустым'),
  en: z.string().optional(),
});
export type Text = z.infer<typeof Text>;

const idOf = (prefix: string) =>
  z
    .string()
    .regex(
      new RegExp(`^${prefix}_[a-z0-9_]+$`),
      `id должен начинаться с «${prefix}_» и содержать только латиницу в нижнем регистре, цифры и «_»`,
    );

export const TargetId = idOf('tar');
export const ClueId = idOf('clue');
export const OpId = idOf('op');
export const CableId = idOf('cable');
export const ExamId = idOf('exam');

export const Act = z.union([z.literal(1), z.literal(2), z.literal(3), z.literal(4)]);

/** Операционная неделя кампании (в концепте 24–30 недель). */
export const Week = z.number().int().min(1).max(30);

/** Значение шкалы 0–100 (MICE, раппорт, тревога, риски). */
export const Scale = z.number().int().min(0).max(100);

/** Флаг последствия, например `fbi_photographed_foxstone_approach`. */
export const FlagId = z.string().regex(/^[a-z0-9_]+$/, 'флаг: латиница в нижнем регистре, цифры и «_»');

export const MiceAxis = z.enum(['money', 'ideology', 'compromise', 'ego']);
export type MiceAxis = z.infer<typeof MiceAxis>;
