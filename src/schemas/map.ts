import { z } from 'zod';
import { Text } from './common';

/** Размер карты в милях: вся сцена от Лисберга до Мэриленда. */
export const MAP_W_MILES = 60;
export const MAP_H_MILES = 40;

export const SiteId = z
  .string()
  .regex(/^site_[a-z0-9_]+$/, 'id точки должен начинаться с «site_» и содержать только латиницу, цифры и «_»');

const Tag = z.string().regex(/^[a-z0-9_]+$/, 'примета: латиница в нижнем регистре, цифры и «_»');

/**
 * Точка на карте. `role`:
 * - `stop` — бытовая точка проверочного маршрута (банк, химчистка, магазин);
 * - `target` — цель операции (место встречи, тайник, объект наблюдения);
 * - `landmark` — ориентир (посольство, Лэнгли, пост ФБР).
 */
export const Site = z.object({
  site_id: SiteId,
  name: Text,
  kind: z.enum([
    'embassy',
    'fbi',
    'cia',
    'bank',
    'bar',
    'park',
    'pharmacy',
    'post_office',
    'bookshop',
    'tobacconist',
    'cleaners',
    'grocery',
    'gas_station',
    'hardware',
    'antiques',
    'cafe',
  ]),
  role: z.enum(['stop', 'target', 'landmark']),
  /** Район города: SDR требует точек в разных районах. */
  district: z.string().regex(/^[a-z_]+$/),
  /** Координаты в милях от левого верхнего угла карты. */
  pos: z.object({ x: z.number().min(0).max(MAP_W_MILES), y: z.number().min(0).max(MAP_H_MILES) }),
  /** Бытовая легенда визита (для точек маршрута). */
  cover_reason: Text.optional(),
  /** Местные приметы: что обычно видно на этой точке. */
  ambient_tags: z.array(Tag).default([]),
});
export type Site = z.infer<typeof Site>;

/** Файл `src/content/map/sites.json`: названия районов и все точки карты. */
export const MapFile = z.object({
  districts: z.record(z.string(), Text),
  sites: z.array(Site).min(1),
});
export type MapFile = z.infer<typeof MapFile>;

/**
 * Примета для карточек наблюдения (`src/content/map/cues.json`):
 * - `tail` — примета хвоста, повторяется на маршруте («дважды — работа противника»);
 * - `noise` — случайные прохожие и машины, никогда не повторяются;
 * - `ambient` — местные приметы конкретной точки.
 */
export const Cue = z.object({
  tag: Tag,
  kind: z.enum(['tail', 'noise', 'ambient']),
  text: Text,
});
export type Cue = z.infer<typeof Cue>;
export const CueFile = z.array(Cue);
