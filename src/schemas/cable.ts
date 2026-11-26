import { z } from 'zod';
import { Act, CableId, Text, Week } from './common';

/**
 * Утренняя почта резидента (GDD, Блок 3, фаза «Утро»): депеши Центра, записки ВГУ,
 * вырезки The Washington Post, донесения агентов, расшифровки перехватов.
 * Файлы `src/content/cables/*.json` содержат массивы.
 */
export const Cable = z.object({
  cable_id: CableId,
  act: Act,
  week: Week,
  kind: z.enum(['directive', 'vgu_note', 'press_clipping', 'agent_report', 'intercept', 'personnel_file']),
  /** От кого: «Центр», «1-й отдел ВГУ», «The Washington Post» и т. п. */
  sender: Text,
  subject: Text,
  /** Текст документа: до 150 слов. */
  body: Text,
});
export type Cable = z.infer<typeof Cable>;

export const CableFile = z.array(Cable);
