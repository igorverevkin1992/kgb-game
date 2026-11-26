/**
 * Сохранения (правило дизайна №3, `docs/best-practices.md`): автосейв с индикатором,
 * чекпоинты на старте каждого акта и каждого игрового месяца, три ручных слота.
 * Режим «Железный занавес» (флаг `mode_ironman` в состоянии) оставляет только автосейв.
 * Логика без React и DOM: хранилище передаётся параметром, поэтому её проверяют unit-тесты.
 */
import { deserialize, serialize, weekDate, type CampaignState, type SaveStorage } from '../engine/campaign';
import type { ContentBundle } from '../engine/content';

export const AUTOSAVE = 'autosave';
export const MANUAL_SLOTS = ['manual-1', 'manual-2', 'manual-3'] as const;
export const MAX_CHECKPOINTS = 12;
const CHECKPOINT_INDEX = 'checkpoints';
export const IRONMAN_FLAG = 'mode_ironman';

export const isIronman = (s: CampaignState) => s.flags.includes(IRONMAN_FLAG);

export interface SlotInfo {
  slot: string;
  act: number;
  week: number;
  phase: CampaignState['phase'];
  savedAt: string;
  ironman: boolean;
  ended: boolean;
}

export function slotInfo(storage: SaveStorage, slot: string, content: ContentBundle): SlotInfo | null {
  const text = storage.read(slot);
  if (!text) return null;
  const r = deserialize(text, content);
  if (!r.ok) return null;
  return {
    slot,
    act: r.state.act,
    week: r.state.week,
    phase: r.state.phase,
    savedAt: r.savedAt,
    ironman: isIronman(r.state),
    ended: r.state.ending !== null,
  };
}

export function loadSlot(storage: SaveStorage, slot: string, content: ContentBundle) {
  const text = storage.read(slot);
  if (!text) return { ok: false as const, error: 'Слот пуст' };
  return deserialize(text, content);
}

export function listCheckpoints(storage: SaveStorage): string[] {
  try {
    const parsed: unknown = JSON.parse(storage.read(CHECKPOINT_INDEX) ?? '[]');
    return Array.isArray(parsed) ? parsed.filter((x): x is string => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

/** Записывает чекпоинт и хранит не больше MAX_CHECKPOINTS последних. */
export function writeCheckpoint(storage: SaveStorage, id: string, state: CampaignState, now = new Date()) {
  storage.write(id, serialize(state, now));
  const list = [...listCheckpoints(storage).filter((x) => x !== id), id];
  for (const old of list.splice(0, Math.max(0, list.length - MAX_CHECKPOINTS))) storage.remove(old);
  storage.write(CHECKPOINT_INDEX, JSON.stringify(list));
}

/**
 * Нужен ли чекпоинт после перехода prev → next: началась неделя нового акта или нового
 * календарного месяца. Возвращает id слота или null.
 */
export function checkpointFor(prev: CampaignState, next: CampaignState, content: ContentBundle): string | null {
  if (isIronman(next) || next.ending) return null;
  if (prev.week === next.week && prev.act === next.act) return null;
  const a = weekDate(content, prev.act, prev.week);
  const b = weekDate(content, next.act, next.week);
  const newMonth = !a || !b || a.getUTCMonth() !== b.getUTCMonth() || a.getUTCFullYear() !== b.getUTCFullYear();
  return next.act !== prev.act || newMonth ? `checkpoint-a${next.act}-w${next.week}` : null;
}

/** Сохраняет после каждого действия: автосейв всегда, чекпоинт — когда начался новый месяц или акт. */
export function persist(storage: SaveStorage, prev: CampaignState | null, next: CampaignState, content: ContentBundle) {
  storage.write(AUTOSAVE, serialize(next));
  const id = prev ? checkpointFor(prev, next, content) : isIronman(next) ? null : `checkpoint-a${next.act}-w${next.week}`;
  if (id) writeCheckpoint(storage, id, next);
}

/** Ручное сохранение в слот. В режиме «Железный занавес» запрещено. */
export function saveManual(storage: SaveStorage, slot: string, state: CampaignState): boolean {
  if (isIronman(state)) return false;
  storage.write(slot, serialize(state));
  return true;
}
