import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import type { RawFile } from '../src/engine/content';

export const DEFAULT_CONTENT_DIR = join(import.meta.dirname, '..', 'src', 'content');

export interface ReadResult {
  entries: RawFile[];
  /** Файлы, которые не удалось разобрать как JSON. */
  broken: { path: string; message: string }[];
}

/** Читает все *.json из папки контента (рекурсивно). Пути — относительно этой папки. */
export function readContentDir(dir = DEFAULT_CONTENT_DIR): ReadResult {
  const result: ReadResult = { entries: [], broken: [] };
  const walk = (d: string) => {
    for (const name of readdirSync(d).sort()) {
      const full = join(d, name);
      if (statSync(full).isDirectory()) walk(full);
      else if (name.endsWith('.json')) {
        const path = relative(dir, full).replace(/\\/g, '/');
        try {
          result.entries.push({ path, data: JSON.parse(readFileSync(full, 'utf8')) });
        } catch (e) {
          result.broken.push({ path, message: (e as Error).message });
        }
      }
    }
  };
  walk(dir);
  return result;
}
