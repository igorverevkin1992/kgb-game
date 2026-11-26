import type { Site } from '../schemas';
import type { ContentBundle } from './content/types';

/** Точка карты по id (или undefined). */
export function siteById(content: ContentBundle, id: string): Site | undefined {
  return content.map.sites.find((s) => s.site_id === id);
}

export function distanceMiles(a: Site, b: Site): number {
  return Math.hypot(a.pos.x - b.pos.x, a.pos.y - b.pos.y);
}

/** Внутри ли точка 25-мильной зоны вокруг посольства (выезд дальше требует согласования с Госдепом). */
export function withinZone(content: ContentBundle, site: Site): boolean {
  const embassy = siteById(content, content.balance.sdr.embassy_site);
  if (!embassy) return true;
  return distanceMiles(embassy, site) <= content.balance.sdr.zone_radius_miles;
}

export type RouteIssue =
  | { kind: 'not_three' }
  | { kind: 'duplicate' }
  | { kind: 'not_a_stop'; site_id: string }
  | { kind: 'few_districts'; districts: number }
  | { kind: 'outside_zone'; site_id: string };

/**
 * Разбор маршрута SDR. Ошибки (`blocking`) не дают утвердить маршрут; предупреждения —
 * подсказки игроку, что маршрут слабый: в одном районе бригада SOG меняет машины, и повтор
 * приметы не виден; точка за 25 милями злит наружку.
 */
export function analyzeRoute(content: ContentBundle, stops: string[]): { blocking: RouteIssue[]; warnings: RouteIssue[] } {
  const blocking: RouteIssue[] = [];
  const warnings: RouteIssue[] = [];
  if (stops.length !== 3) blocking.push({ kind: 'not_three' });
  if (new Set(stops).size !== stops.length) blocking.push({ kind: 'duplicate' });
  const sites: Site[] = [];
  for (const id of stops) {
    const site = siteById(content, id);
    if (!site || site.role !== 'stop') blocking.push({ kind: 'not_a_stop', site_id: id });
    else sites.push(site);
  }
  const districts = new Set(sites.map((s) => s.district)).size;
  if (sites.length && districts < content.balance.sdr.min_districts_for_double_sighting) {
    warnings.push({ kind: 'few_districts', districts });
  }
  for (const site of sites) if (!withinZone(content, site)) warnings.push({ kind: 'outside_zone', site_id: site.site_id });
  return { blocking, warnings };
}
