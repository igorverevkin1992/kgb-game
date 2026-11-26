import type { Site } from '../../../schemas';
import { withinZone } from '../../../engine/map';
import { content, useLocalized } from '../../store';

/**
 * Видимая часть карты в милях: от Вены до Мэриленда. Точки за краем листа (Лисберг)
 * рисуются стрелкой на краю. 25-мильная граница видна дугой у левого края.
 */
const VIEW = { x: 5, y: 7, w: 36, h: 22 };

/** Цвета районов: булавки на карте и заголовки в списке точек. */
const DISTRICT_COLORS = ['#7a4f9e', '#2f6f8f', '#9a5a22', '#4f7a3a', '#a03b5a', '#3b5a9e', '#6f6f22', '#555555'];
export function districtColor(district: string): string {
  const i = Object.keys(content.map.districts).indexOf(district);
  return DISTRICT_COLORS[(i < 0 ? 0 : i) % DISTRICT_COLORS.length]!;
}

/** Координаты в пределах листа: точка за краем прижимается к краю. */
const clampToView = (x: number, y: number) => ({
  x: Math.min(Math.max(x, VIEW.x + 0.5), VIEW.x + VIEW.w - 0.5),
  y: Math.min(Math.max(y, VIEW.y + 0.5), VIEW.y + VIEW.h - 0.5),
  clamped: x < VIEW.x || x > VIEW.x + VIEW.w || y < VIEW.y || y > VIEW.y + VIEW.h,
});
export const MAP_PX_W = 1040;
export const MAP_PX_H = Math.round((MAP_PX_W * VIEW.h) / VIEW.w);
const K = MAP_PX_W / VIEW.w;
const px = (x: number, y: number) => [(x - VIEW.x) * K, (y - VIEW.y) * K] as const;
/** Путь в милях → путь в пикселях: «M 0 9 C 8 8 …» */
const path = (d: string) =>
  d.replace(/(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)/g, (_, x: string, y: string) => px(Number(x), Number(y)).map((v) => v.toFixed(1)).join(' '));

export interface MapCanvasProps {
  /** Точки маршрута по порядку (номера 1–3). */
  route: string[];
  /** Цель выбранной операции. */
  targetId: string | null;
  /** Можно ли сейчас кликать по бытовым точкам. */
  selectable: boolean;
  onSelectStop?: (siteId: string) => void;
  /** Сколько точек маршрута уже пройдено на выезде (рисуется путь машины). */
  progress?: number;
  /** Красные отметки наружки и где резидент уже засветился. */
  sogMarks: number;
  visitedSites: string[];
}

const ROLE_ORDER: Record<Site['role'], number> = { stop: 0, target: 1, landmark: 2 };

export function MapCanvas({ route, targetId, selectable, onSelectStop, progress, sogMarks, visitedSites, zoneLabel }: MapCanvasProps & { zoneLabel: string }) {
  const loc = useLocalized();
  const embassy = content.map.sites.find((s) => s.site_id === content.balance.sdr.embassy_site);
  const sites = [...content.map.sites].sort((a, b) => ROLE_ORDER[a.role] - ROLE_ORDER[b.role]);
  const byId = new Map(content.map.sites.map((s) => [s.site_id, s]));

  const routeSites = route.map((id) => byId.get(id)).filter((s) => s !== undefined);
  const target = targetId ? byId.get(targetId) : undefined;
  const chain = [embassy, ...routeSites, target].filter((s) => s !== undefined);
  const drivenUpTo = progress === undefined ? -1 : progress; // сколько отрезков от посольства уже проехано

  // Отметки наружки — у мест, где резидент уже бывал, иначе у посольства.
  const anchors = [...visitedSites.map((id) => byId.get(id)), embassy].filter((s) => s !== undefined);
  const marks = Array.from({ length: sogMarks }, (_, i) => {
    const a = anchors[i % anchors.length]!;
    const [x, y] = px(a.pos.x, a.pos.y);
    return [x + 16 + (i % 2) * 10, y - 14 - Math.floor(i / 2) * 9] as const;
  });

  return (
    <svg viewBox={`0 0 ${MAP_PX_W} ${MAP_PX_H}`} className="map-canvas" data-testid="map-canvas" role="img">
      <defs>
        <pattern id="map-grid" width={K * 2} height={K * 2} patternUnits="userSpaceOnUse">
          <path d={`M ${K * 2} 0 L 0 0 0 ${K * 2}`} fill="none" stroke="#b9b79d" strokeWidth="0.6" />
        </pattern>
      </defs>
      <rect width={MAP_PX_W} height={MAP_PX_H} fill="#d8d6bc" />
      <rect width={MAP_PX_W} height={MAP_PX_H} fill="url(#map-grid)" />

      {/* Парки */}
      <path d={path('M 34.2 10 C 35 12, 34.6 14.5, 33.8 17.2')} stroke="#a9b88f" strokeWidth={K * 0.9} fill="none" strokeLinecap="round" opacity="0.8" />
      <ellipse cx={px(19.6, 17.6)[0]} cy={px(19.6, 17.6)[1]} rx={K * 1.6} ry={K * 1} fill="#a9b88f" opacity="0.7" />

      {/* Потомак */}
      <path
        d={path('M 0 9 C 8 8 14 9 20 10.5 S 26 13 29 15.5 S 31.5 17.6 32.8 18.4 S 33.8 21 33.9 24 S 34.5 30 35 32')}
        fill="none"
        stroke="#86a6b8"
        strokeWidth={K * 0.55}
      />
      {/* Кольцевая I-495, I-66, Лисбург-пайк, Висконсин-авеню */}
      <ellipse cx={px(31, 16.5)[0]} cy={px(31, 16.5)[1]} rx={K * 9.5} ry={K * 8.8} fill="none" stroke="#c49a5a" strokeWidth="3" opacity="0.85" />
      <path d={path('M 0 21 L 15 21 L 24 19.5 L 31 18.8')} fill="none" stroke="#c49a5a" strokeWidth="3" opacity="0.85" />
      <path d={path('M 3 11.5 C 12 13 20 16.5 28 20')} fill="none" stroke="#b7b59a" strokeWidth="2.2" />
      <path d={path('M 31.4 9 L 32.9 18.2')} fill="none" stroke="#b7b59a" strokeWidth="2.2" />

      {/* 25-мильная зона вокруг посольства */}
      {embassy && (
        <circle
          cx={px(embassy.pos.x, embassy.pos.y)[0]}
          cy={px(embassy.pos.x, embassy.pos.y)[1]}
          r={K * content.balance.sdr.zone_radius_miles}
          fill="none"
          stroke="#8e2b22"
          strokeWidth="2.5"
          strokeDasharray="14 9"
          data-testid="zone-circle"
        />
      )}
      {embassy && (
        <text
          className="map-canvas__zone-label"
          transform={`translate(${px(embassy.pos.x - content.balance.sdr.zone_radius_miles, embassy.pos.y)[0] + 22} ${px(0, embassy.pos.y)[1]}) rotate(-90)`}
          textAnchor="middle"
        >
          {zoneLabel}
        </text>
      )}

      {/* Маршрут: посольство → 1 → 2 → 3 → цель. Пройденная часть — сплошной линией. */}
      {chain.slice(1).map((site, i) => {
        const from = chain[i]!;
        const a = clampToView(from.pos.x, from.pos.y);
        const b = clampToView(site.pos.x, site.pos.y);
        const [x1, y1] = px(a.x, a.y);
        const [x2, y2] = px(b.x, b.y);
        const driven = i < drivenUpTo;
        const toTarget = site === target;
        return (
          <line
            key={`${from.site_id}-${site.site_id}`}
            x1={x1}
            y1={y1}
            x2={x2}
            y2={y2}
            stroke={driven ? '#2a2620' : toTarget ? '#8e2b22' : '#4a4436'}
            strokeWidth={driven ? 4 : 2.5}
            strokeDasharray={driven ? undefined : '7 6'}
          />
        );
      })}

      {/* Точки */}
      {sites.map((site) => {
        const pos = clampToView(site.pos.x, site.pos.y);
        const [x, y] = px(pos.x, pos.y);
        const order = route.indexOf(site.site_id);
        const isTarget = site.site_id === targetId;
        const outside = embassy ? !withinZone(content, site) : false;
        const clickable = selectable && site.role === 'stop';
        const common = {
          'data-testid': `site-${site.site_id}`,
          'data-role': site.role,
          className: `map-site map-site--${site.role}${clickable ? ' map-site--clickable' : ''}${order >= 0 ? ' map-site--picked' : ''}${isTarget ? ' map-site--target-active' : ''}`,
          onClick: clickable ? () => onSelectStop?.(site.site_id) : undefined,
        };
        const label = loc(site.name);
        if (site.role === 'landmark') {
          const color = site.kind === 'embassy' ? '#8e2b22' : '#2f5f9e';
          return (
            <g key={site.site_id} {...common}>
              <title>{label}</title>
              <rect x={x - 8} y={y - 8} width="16" height="16" fill={color} transform={`rotate(45 ${x} ${y})`} />
              <text x={x + 13} y={y + 4} className="map-canvas__label map-canvas__label--landmark">
                {label.split(',')[0]}
              </text>
            </g>
          );
        }
        if (site.role === 'target') {
          return (
            <g key={site.site_id} {...common}>
              <title>{label}</title>
              <circle cx={x} cy={y} r={isTarget ? 13 : 9} fill={isTarget ? '#c9a227' : '#b59a4a'} stroke="#2a2620" strokeWidth="2" />
              {isTarget && (
                <text x={x + 17} y={y + 5} className="map-canvas__label map-canvas__label--target">
                  {label}
                </text>
              )}
            </g>
          );
        }
        const color = districtColor(site.district);
        const district = loc(content.map.districts[site.district] ?? { ru: site.district });
        return (
          <g key={site.site_id} {...common}>
            <title>{`${label} · ${district}`}</title>
            {pos.clamped && (
              <>
                <path d={`M${x - 14} ${y} l10 -9 v18 z`} fill={color} />
                <text x={x + 14} y={y - 12} className="map-canvas__label">
                  ← {district}
                </text>
              </>
            )}
            <circle
              cx={x}
              cy={y}
              r={order >= 0 ? 12 : 8}
              fill={order >= 0 ? '#2a2620' : color}
              stroke={outside ? '#8e2b22' : '#f2eee2'}
              strokeWidth={outside ? 3 : 2}
              strokeDasharray={outside ? '3 2' : undefined}
            />
            {order >= 0 && (
              <text x={x} y={y + 5} textAnchor="middle" className="map-canvas__order">
                {order + 1}
              </text>
            )}
            {clickable && <circle cx={x} cy={y} r="16" fill="transparent" />}
          </g>
        );
      })}

      {/* Отметки наружки ФБР */}
      {marks.map(([x, y], i) => (
        <path key={i} data-sog-mark d={`M${x - 7} ${y - 7}L${x + 7} ${y + 7}M${x + 7} ${y - 7}L${x - 7} ${y + 7}`} stroke="#c0281c" strokeWidth="3.5" />
      ))}
    </svg>
  );
}
