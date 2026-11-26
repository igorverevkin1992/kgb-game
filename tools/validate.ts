/**
 * Проверка игрового контента: `npm run validate` (или `npm run validate -- путь/к/папке`).
 * `--en` — дополнительно напомнить о текстах без английского перевода (английская версия — позже).
 * Выход с кодом 1, если есть ошибки. Предупреждения не мешают сборке.
 */
import { resolve } from 'node:path';
import { formatIssue, validateContent } from '../src/engine/content';
import { DEFAULT_CONTENT_DIR, readContentDir } from './content-fs';

const args = process.argv.slice(2);
const pathArg = args.find((a) => !a.startsWith('--'));
const dir = pathArg ? resolve(pathArg) : DEFAULT_CONTENT_DIR;
const { entries, broken } = readContentDir(dir);
const report = validateContent(entries, { translation: args.includes('--en') });

const red = (s: string) => `\x1b[31m${s}\x1b[0m`;
const yellow = (s: string) => `\x1b[33m${s}\x1b[0m`;
const green = (s: string) => `\x1b[32m${s}\x1b[0m`;

console.log(`Проверка контента: ${dir}\n`);

const errors = [...broken.map((b) => `${b.path}: файл не читается как JSON — ${b.message} [файл]`), ...report.errors.map(formatIssue)];

if (report.content) {
  const c = report.content;
  console.log(
    `Акты: ${c.campaign.acts.length} · цели: ${c.targets.length} · улики: ${c.clues.length} · ` +
      `депеши: ${c.cables.length} · операции: ${c.ops.length} · экзамены: ${c.polygraph.length}\n`,
  );
}

if (errors.length) {
  console.log(red(`✖ Ошибки (${errors.length}):`));
  for (const e of errors) console.log(red(`  • ${e}`));
  console.log();
}
if (report.warnings.length) {
  console.log(yellow(`⚠ Предупреждения (${report.warnings.length}):`));
  for (const w of report.warnings) console.log(yellow(`  • ${formatIssue(w)}`));
  console.log();
}
if (!errors.length) console.log(green('✔ Контент в порядке: тупиков нет, «Правило трёх улик» соблюдено.'));

process.exit(errors.length ? 1 : 0);
