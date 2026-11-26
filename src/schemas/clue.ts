import { z } from 'zod';
import { CableId, ClueId, MiceAxis, OpId, TargetId, Text } from './common';

/**
 * Откуда игрок получает улику. Это три независимых пути из «Правила трёх улик» (GDD, Блок 2):
 * - `agent` — от завербованного агента (`from` = target_id агента);
 * - `document` — из утренней почты: депеша, вырезка, справка, перехват (`from` = cable_id);
 * - `field` — полевая разведка на карте SDR (`from` = op_id).
 */
export const ClueSource = z.discriminatedUnion('channel', [
  z.object({ channel: z.literal('agent'), from: TargetId }),
  z.object({ channel: z.literal('document'), from: CableId }),
  z.object({ channel: z.literal('field'), from: OpId }),
]);
export type ClueSource = z.infer<typeof ClueSource>;

/** Улика для доски MICE. Файлы `src/content/clues/*.json` содержат массивы улик. */
export const Clue = z.object({
  clue_id: ClueId,
  source: ClueSource,
  title: Text,
  /** Текст карточки: до 150 слов (риск №2, «стена текста»). */
  text: Text,
  /** Какие оси MICE и у каких целей эта улика вскрывает. */
  reveals: z.array(z.object({ target_id: TargetId, axis: MiceAxis })).default([]),
});
export type Clue = z.infer<typeof Clue>;

export const ClueFile = z.array(Clue);
