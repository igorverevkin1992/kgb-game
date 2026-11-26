import type { ModuleId } from '../engine/modules';
import type { I18nKey } from '../i18n';

/** Что может быть открыто поверх стола: шесть модулей из GDD + лоток входящих документов. */
export type View = ModuleId | 'inbox';

/** Порядок на краю стола и горячие клавиши 1–7. */
export const VIEWS: readonly View[] = ['map', 'mice', 'cipher', 'finance', 'dialog', 'counterintel', 'inbox'];

export const hotkeyOf = (v: View) => VIEWS.indexOf(v) + 1;

export function viewByHotkey(key: string): View | null {
  const n = Number(key);
  return Number.isInteger(n) && n >= 1 && n <= VIEWS.length ? (VIEWS[n - 1] ?? null) : null;
}

export const viewName = (v: View) => (v === 'inbox' ? 'inbox.name' : `module.${v}.name`) as I18nKey;
export const viewObject = (v: View) => (v === 'inbox' ? 'inbox.object' : `module.${v}.object`) as I18nKey;
