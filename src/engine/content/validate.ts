import { bundleFromEntries, parseBundle } from './parse';
import { checkRules, type RuleOptions } from './rules';
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
export function validateContent(entries: RawFile[], opts: RuleOptions = {}): ValidationReport {
  const parsed = parseBundle(bundleFromEntries(entries));
  const issues = [...parsed.issues];
  const schemaOk = parsed.bundle !== null && !issues.some((i) => i.level === 'error');
  if (parsed.bundle && schemaOk) issues.push(...checkRules(parsed.bundle, parsed.fileOf, opts));
  return {
    content: schemaOk ? parsed.bundle : null,
    issues,
    errors: issues.filter((i) => i.level === 'error'),
    warnings: issues.filter((i) => i.level === 'warning'),
  };
}

/** Русские названия проверок для вывода валидатора. */
const RULE_RU: Record<Issue['rule'], string> = {
  schema: 'формат',
  layout: 'файлы',
  duplicate: 'повтор',
  refs: 'ссылки',
  unlock: 'открытие цели',
  'three-clue': 'три улики',
  'mice-three-clue': 'три улики на мотив',
  softlock: 'тупик',
  robustness: 'устойчивость',
  unreachable: 'недостижимо',
  sdr: 'проверочный маршрут',
  weeks: 'недели',
  'text-length': 'длина текста',
  translation: 'перевод',
  polygraph: 'полиграф',
  balance: 'баланс',
};

export function formatIssue(i: Issue): string {
  const place = [i.file, i.where].filter(Boolean).join(' → ');
  return `${place ? `${place}: ` : ''}${i.message} [${RULE_RU[i.rule]}]`;
}
