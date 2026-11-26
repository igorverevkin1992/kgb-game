import { z } from 'zod';
import type { ContentBundle } from '../content';
import { CampaignState, initialTargetState } from './state';

export const SAVE_FORMAT = 'liniya-kr-save';
export const SAVE_VERSION = 1;

const SaveFile = z.object({
  format: z.literal(SAVE_FORMAT),
  version: z.literal(SAVE_VERSION),
  saved_at: z.string(),
  state: CampaignState,
});

/** Сохранение в строку JSON. */
export function serialize(state: CampaignState, now = new Date()): string {
  return JSON.stringify({ format: SAVE_FORMAT, version: SAVE_VERSION, saved_at: now.toISOString(), state });
}

export type LoadResult = { ok: true; state: CampaignState; savedAt: string } | { ok: false; error: string };

/**
 * Загрузка сохранения с проверкой: повреждённый файл или сохранение от другой версии контента
 * не должны молча сломать игру.
 */
export function deserialize(text: string, content: ContentBundle): LoadResult {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return { ok: false, error: 'Сохранение повреждено: это не JSON' };
  }
  const parsed = SaveFile.safeParse(json);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    return { ok: false, error: `Сохранение не подходит к этой версии игры (${first?.path.join('.') || 'файл'}: ${first?.message})` };
  }
  const { state } = parsed.data;

  const known = new Set([
    ...content.targets.map((t) => t.target_id),
    ...content.clues.map((c) => c.clue_id),
    ...content.cables.map((c) => c.cable_id),
    ...content.ops.map((o) => o.op_id),
  ]);
  const referenced = [
    ...Object.keys(state.targets),
    ...state.clues,
    ...state.delivered_cables,
    ...state.planned_ops,
    ...Object.keys(state.op_results),
  ];
  const missing = referenced.filter((id) => !known.has(id));
  if (missing.length) {
    return { ok: false, error: `Сохранение ссылается на удалённый контент: ${[...new Set(missing)].join(', ')}` };
  }
  // Цели, добавленные в контент после сохранения, получают стартовое состояние.
  for (const t of content.targets) {
    state.targets[t.target_id] ??= initialTargetState(content, t.target_id);
  }
  return { ok: true, state, savedAt: parsed.data.saved_at };
}

/** Место хранения сохранений: localStorage в браузере, файлы в Electron (шаг 10), память в тестах. */
export interface SaveStorage {
  read(slot: string): string | null;
  write(slot: string, data: string): void;
  remove(slot: string): void;
}

export function memoryStorage(): SaveStorage {
  const map = new Map<string, string>();
  return {
    read: (slot) => map.get(slot) ?? null,
    write: (slot, data) => void map.set(slot, data),
    remove: (slot) => void map.delete(slot),
  };
}
