import { bundleFromEntries, parseBundle } from './parse';
import { checkRules } from './rules';
import type { ContentBundle, Issue, RawFile } from './types';

export interface ValidationReport {
  /** null, если контент не удалось собрать из-за ошибок схемы. */
  content: ContentBundle | null;
  issues: Issue[];
  errors: Issue[];
  warnings: Issue[];
}

/**
 * Полная проверка контента: сначала каждый файл по схеме, затем связи и правила дизайна.
 * Правила запускаются только если все файлы прошли схему, иначе ошибки будут путаными.
 */
export function validateContent(entries: RawFile[]): ValidationReport {
  const parsed = parseBundle(bundleFromEntries(entries));
  const issues = [...parsed.issues];
  const schemaOk = parsed.bundle !== null && !issues.some((i) => i.level === 'error');
  if (parsed.bundle && schemaOk) issues.push(...checkRules(parsed.bundle, parsed.fileOf));
  return {
    content: schemaOk ? parsed.bundle : null,
    issues,
    errors: issues.filter((i) => i.level === 'error'),
    warnings: issues.filter((i) => i.level === 'warning'),
  };
}

export function formatIssue(i: Issue): string {
  const place = [i.file, i.where].filter(Boolean).join(' → ');
  return `${place ? `${place}: ` : ''}${i.message} [${i.rule}]`;
}
