import ru from './ru.json';
import en from './en.json';

export type Lang = 'ru' | 'en';
export type I18nKey = keyof typeof ru;

// Английский словарь обязан содержать те же ключи, что и русский (проверяется тестом).
const dictionaries: Record<Lang, Record<string, string>> = { ru, en };

export function parseLang(value: string | null | undefined): Lang {
  return value === 'en' ? 'en' : 'ru';
}

/** Перевод по ключу с подстановкой параметров вида {name}. */
export function translate(lang: Lang, key: I18nKey, params: Record<string, string | number> = {}): string {
  const template = dictionaries[lang][key] ?? dictionaries.ru[key] ?? key;
  return template.replace(/\{(\w+)\}/g, (_, name: string) => String(params[name] ?? `{${name}}`));
}

export const dictionaryKeys = (lang: Lang): string[] => Object.keys(dictionaries[lang]);
