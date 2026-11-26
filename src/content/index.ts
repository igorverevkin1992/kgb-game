import { formatIssue, validateContent, type ContentBundle, type RawFile } from '../engine/content';

// Vite собирает все JSON из этой папки в билд. Пути вида './targets/tar_vargas_ellen.json'.
const modules = import.meta.glob<unknown>('./**/*.json', { eager: true, import: 'default' });

const entries: RawFile[] = Object.entries(modules).map(([path, data]) => ({ path, data }));

/**
 * Загружает и проверяет игровой контент. Те же проверки, что и `npm run validate`:
 * сломанный контент не должен попасть в игру молча.
 */
export function loadContent(): ContentBundle {
  const report = validateContent(entries);
  if (!report.content || report.errors.length) {
    throw new Error(`Контент игры содержит ошибки:\n${report.errors.map(formatIssue).join('\n')}`);
  }
  if (import.meta.env?.DEV) {
    for (const w of report.warnings) console.warn(`[контент] ${formatIssue(w)}`);
  }
  return report.content;
}
