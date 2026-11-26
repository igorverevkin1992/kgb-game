/**
 * Реестр модулей рабочего стола резидента (GDD, Блок 3 «Шесть модулей рабочего стола»).
 *
 * Модули вводятся послойно по актам (Блок 4 + риск №2 «информационная перегрузка»):
 * в первые 45 минут игрок видит только карту SDR, шифроузел и базовую доску MICE.
 * Финансовый журнал и магнитофон по таблице актов открываются во II акте, пульт
 * «Окно арестов / Полиграф» в III–IV. В вертикальном срезе (MVP) их базовые версии
 * понадобятся раньше; это решим флагами разблокировки на шаге 2 (движок кампании).
 */

export type Act = 1 | 2 | 3 | 4;

export const ACTS: readonly Act[] = [1, 2, 3, 4];

export type ModuleId = 'map' | 'mice' | 'cipher' | 'finance' | 'dialog' | 'counterintel';

export interface DeskModule {
  id: ModuleId;
  /** Акт, с которого модуль доступен игроку. */
  unlockAct: Act;
}

export const DESK_MODULES: readonly DeskModule[] = [
  { id: 'map', unlockAct: 1 },
  { id: 'mice', unlockAct: 1 },
  { id: 'cipher', unlockAct: 1 },
  { id: 'finance', unlockAct: 2 },
  { id: 'dialog', unlockAct: 2 },
  { id: 'counterintel', unlockAct: 3 },
];

export function isModuleUnlocked(module: DeskModule, act: Act): boolean {
  return act >= module.unlockAct;
}

export function unlockedModules(act: Act): DeskModule[] {
  return DESK_MODULES.filter((m) => isModuleUnlocked(m, act));
}

export function getModule(id: ModuleId): DeskModule {
  const found = DESK_MODULES.find((m) => m.id === id);
  if (!found) throw new Error(`Unknown desk module: ${id}`);
  return found;
}

export function parseAct(value: string | null | undefined): Act {
  const n = Number(value);
  return (ACTS as readonly number[]).includes(n) ? (n as Act) : 1;
}
