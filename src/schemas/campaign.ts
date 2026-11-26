import { z } from 'zod';
import { Act, TargetId, Text, Week } from './common';

/** Структура кампании (GDD, Блок 4): акты, их недели и цель, без которой акт не закончить. */
export const Campaign = z.object({
  acts: z
    .array(
      z.object({
        act: Act,
        title: Text,
        weeks: z.object({ from: Week, to: Week }),
        /** Календарная дата первой недели акта (между актами бывают сюжетные скачки во времени). */
        start_date: z.iso.date(),
        /** Цель акта: завербовать хотя бы одну из перечисленных целей. */
        goal: z.object({ recruit_any_of: z.array(TargetId).min(1) }),
      }),
    )
    .min(1),
});
export type Campaign = z.infer<typeof Campaign>;
