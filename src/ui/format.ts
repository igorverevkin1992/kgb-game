import type { Lang } from '../i18n';

/** Русское склонение после числа: 1 доллар, 2 доллара, 5 долларов. */
export function plural(n: number, one: string, few: string, many: string): string {
  const m10 = n % 10;
  const m100 = n % 100;
  if (m10 === 1 && m100 !== 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

/** Сумма в долларах словами: «40 000 долларов» (по-английски — «$40,000»). */
export function formatUsd(n: number, lang: Lang): string {
  if (lang === 'en') return `$${n.toLocaleString('en-US')}`;
  return `${n.toLocaleString('ru-RU')} ${plural(Math.abs(n), 'доллар', 'доллара', 'долларов')}`;
}
