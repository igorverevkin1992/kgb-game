/**
 * Плейсхолдер-арт предметов кабинета (SVG). Финальный арт — шаг 9; размеры и места предметов
 * на столе уже окончательные, поэтому замена картинки не тронет раскладку и тесты.
 */

const svg = { width: '100%', height: '100%', preserveAspectRatio: 'xMidYMid meet' } as const;

/** Складная карта Вашингтона и Северной Вирджинии. `sogMarks` — красные отметки наружки ФБР. */
export function MapArt({ sogMarks = 0 }: { sogMarks?: number }) {
  const marks = [
    [300, 120],
    [210, 230],
    [360, 250],
    [150, 140],
    [400, 170],
  ].slice(0, sogMarks);
  return (
    <svg viewBox="0 0 500 400" {...svg} aria-hidden>
      <rect x="6" y="6" width="488" height="388" fill="#d6d6bd" stroke="#9c9a80" />
      {/* сгибы */}
      <path d="M168 6V394M332 6V394M6 200H494" stroke="#b5b39a" strokeWidth="2" />
      {/* Потомак */}
      <path d="M40 30C120 80 170 120 200 170S240 240 260 280 330 360 380 394" fill="none" stroke="#7fa1b5" strokeWidth="14" />
      {/* дороги */}
      <path d="M20 250L480 160M100 380L300 20M250 394L460 60M30 120L470 330" stroke="#c49a5a" strokeWidth="3" opacity="0.8" />
      <path d="M60 300L440 290M180 30L230 390" stroke="#a7a58e" strokeWidth="2" />
      {/* парки */}
      <ellipse cx="110" cy="320" rx="40" ry="26" fill="#a8b78f" opacity="0.7" />
      <ellipse cx="400" cy="90" rx="34" ry="22" fill="#a8b78f" opacity="0.7" />
      {/* 25-мильный радиус */}
      <circle cx="270" cy="190" r="170" fill="none" stroke="#8e2b22" strokeWidth="2.5" strokeDasharray="10 7" />
      {/* булавки: посольство и цели */}
      <circle cx="285" cy="150" r="7" fill="#8e2b22" />
      <circle cx="230" cy="215" r="6" fill="#c9a227" />
      <circle cx="205" cy="255" r="6" fill="#c9a227" />
      {marks.map(([x, y], i) => (
        <g key={i} data-sog-mark>
          <path d={`M${x! - 9} ${y! - 9}L${x! + 9} ${y! + 9}M${x! + 9} ${y! - 9}L${x! - 9} ${y! + 9}`} stroke="#c0281c" strokeWidth="4" />
        </g>
      ))}
    </svg>
  );
}

/** Пробковая доска с карточками и красными нитями. `cards` — сколько досье уже приколото. */
export function CorkBoardArt({ cards = 0 }: { cards?: number }) {
  const slots = [
    [70, 60],
    [250, 40],
    [440, 70],
    [150, 150],
    [360, 160],
    [530, 140],
  ];
  const shown = slots.slice(0, Math.max(cards, 0));
  return (
    <svg viewBox="0 0 680 260" {...svg} aria-hidden>
      <defs>
        <pattern id="cork" width="8" height="8" patternUnits="userSpaceOnUse">
          <rect width="8" height="8" fill="#a37c4f" />
          <circle cx="2" cy="3" r="1.1" fill="#8b663e" />
          <circle cx="6" cy="6" r="0.9" fill="#b8915f" />
        </pattern>
      </defs>
      <rect x="0" y="0" width="680" height="260" rx="4" fill="#5a3f27" />
      <rect x="12" y="12" width="656" height="236" fill="url(#cork)" />
      {shown.length > 1 &&
        shown.slice(1).map(([x, y], i) => (
          <line key={i} x1={shown[i]![0]! + 45} y1={shown[i]![1]! + 10} x2={x! + 45} y2={y! + 10} stroke="#b3271c" strokeWidth="2" />
        ))}
      {shown.map(([x, y], i) => (
        <g key={i}>
          <rect x={x} y={y} width="90" height="62" fill="#e6e1d3" transform={`rotate(${(i % 3) - 1} ${x} ${y})`} />
          <line x1={x! + 10} y1={y! + 22} x2={x! + 78} y2={y! + 22} stroke="#8a8578" />
          <line x1={x! + 10} y1={y! + 34} x2={x! + 70} y2={y! + 34} stroke="#8a8578" />
          <line x1={x! + 10} y1={y! + 46} x2={x! + 60} y2={y! + 46} stroke="#8a8578" />
          <circle cx={x! + 45} cy={y! + 8} r="5" fill="#b3271c" />
        </g>
      ))}
      {shown.length === 0 && (
        <g opacity="0.55">
          <rect x="290" y="90" width="100" height="70" fill="#e6e1d3" transform="rotate(-2 290 90)" />
          <circle cx="340" cy="98" r="5" fill="#2f5f9e" />
        </g>
      )}
    </svg>
  );
}

/** Роторная шифромашина «Фиалка» М-125 с телетайпной лентой. */
export function FialkaArt() {
  return (
    <svg viewBox="0 0 300 290" {...svg} aria-hidden>
      <rect x="20" y="60" width="260" height="210" rx="10" fill="#22241f" stroke="#0e0f0c" strokeWidth="3" />
      <rect x="40" y="76" width="220" height="62" rx="4" fill="#141512" />
      {Array.from({ length: 10 }, (_, i) => (
        <g key={i}>
          <rect x={48 + i * 21} y="82" width="16" height="50" rx="3" fill="#3b3d36" />
          <line x1={48 + i * 21} y1="96" x2={64 + i * 21} y2="96" stroke="#6a6c62" />
          <line x1={48 + i * 21} y1="118" x2={64 + i * 21} y2="118" stroke="#6a6c62" />
        </g>
      ))}
      {Array.from({ length: 3 }, (_, row) =>
        Array.from({ length: 10 - row }, (_, i) => (
          <circle key={`${row}-${i}`} cx={58 + row * 10 + i * 21} cy={170 + row * 28} r="8" fill="#d9d4c5" stroke="#0e0f0c" />
        )),
      )}
      {/* телетайпная лента */}
      <path d="M210 60C215 30 250 22 262 4" fill="none" stroke="#e6e1d3" strokeWidth="14" />
      <path d="M212 50l8 -6M220 38l9 -5M232 27l9 -3M246 17l8 -4" stroke="#6d675a" strokeWidth="2" />
      <text x="150" y="262" fill="#8a8578" fontSize="13" textAnchor="middle" fontFamily="PT Sans Narrow">
        М-125
      </text>
    </svg>
  );
}

/** Тетрадь учёта спецфонда. */
export function LedgerArt() {
  return (
    <svg viewBox="0 0 240 290" {...svg} aria-hidden>
      <rect x="18" y="14" width="210" height="266" rx="4" fill="#8a6a3b" />
      <rect x="10" y="8" width="210" height="266" rx="4" fill="#b8955a" stroke="#7a5c30" strokeWidth="2" />
      <rect x="10" y="8" width="20" height="266" fill="#7a5c30" />
      <rect x="62" y="60" width="128" height="74" fill="#e6e1d3" stroke="#7a5c30" />
      <text x="126" y="88" fontSize="15" textAnchor="middle" fill="#2a2620" fontFamily="PT Sans Narrow">
        ДЕЛО №
      </text>
      <line x1="76" y1="110" x2="176" y2="110" stroke="#2a2620" />
      <text x="126" y="250" fontSize="12" textAnchor="middle" fill="#5a4220" fontFamily="PT Sans Narrow">
        ХРАНИТЬ ВЕЧНО
      </text>
    </svg>
  );
}

/** Катушечный магнитофон «Тембр-2М». */
export function RecorderArt() {
  const reel = (cx: number) => (
    <g>
      <circle cx={cx} cy="100" r="58" fill="#1d1e1a" stroke="#575a4f" strokeWidth="3" />
      <circle cx={cx} cy="100" r="40" fill="#5b4a33" />
      <circle cx={cx} cy="100" r="12" fill="#c9c4b4" />
      {[0, 120, 240].map((a) => (
        <rect key={a} x={cx - 4} y="70" width="8" height="22" fill="#1d1e1a" transform={`rotate(${a} ${cx} 100)`} />
      ))}
    </g>
  );
  return (
    <svg viewBox="0 0 320 270" {...svg} aria-hidden>
      <rect x="8" y="20" width="304" height="240" rx="10" fill="#4f5640" stroke="#2c3124" strokeWidth="3" />
      {reel(90)}
      {reel(230)}
      <path d="M90 158H230" stroke="#3a2c1e" strokeWidth="3" />
      <rect x="40" y="186" width="240" height="56" rx="4" fill="#343a2b" />
      {[0, 1, 2, 3, 4].map((i) => (
        <rect key={i} x={56 + i * 44} y="200" width="32" height="26" rx="3" fill="#c9c4b4" />
      ))}
    </svg>
  );
}

/** Стальной шкаф с картотекой («Окно арестов», полиграф). */
export function ConsoleArt() {
  return (
    <svg viewBox="0 0 260 260" {...svg} aria-hidden>
      <rect x="10" y="6" width="240" height="250" rx="4" fill="#5d6352" stroke="#2c3124" strokeWidth="3" />
      {[0, 1, 2].map((r) =>
        [0, 1].map((c) => (
          <g key={`${r}${c}`}>
            <rect x={26 + c * 110} y={22 + r * 76} width="98" height="64" rx="2" fill="#4a5042" stroke="#2c3124" />
            <rect x={60 + c * 110} y={46 + r * 76} width="30" height="10" rx="2" fill="#c9c4b4" />
          </g>
        )),
      )}
    </svg>
  );
}

/** Лоток входящих документов. `count` — непрочитанные (толщина стопки). */
export function InboxArt({ count = 0 }: { count?: number }) {
  const sheets = Math.min(count, 6);
  return (
    <svg viewBox="0 0 260 200" {...svg} aria-hidden>
      <path d="M10 70L30 190H230L250 70Z" fill="#3b2f24" stroke="#1c140d" strokeWidth="2" />
      {Array.from({ length: sheets }, (_, i) => (
        <rect
          key={i}
          x={40 + (i % 2) * 6}
          y={110 - i * 7}
          width="176"
          height="60"
          fill={i % 3 === 2 ? '#eee7d6' : '#d9d4c5'}
          stroke="#8a8578"
          transform={`rotate(${(i % 3) - 1} 128 ${140 - i * 7})`}
        />
      ))}
      <path d="M10 70L30 190H230L250 70" fill="none" stroke="#1c140d" strokeWidth="3" />
      <rect x="18" y="160" width="224" height="30" fill="#4a3b2d" />
    </svg>
  );
}

/** Окно на Висконсин-авеню за двойной рамой, с жалюзи. */
export function WindowArt() {
  return (
    <svg viewBox="0 0 180 240" {...svg} aria-hidden>
      <rect x="4" y="4" width="172" height="232" fill="#1a2026" stroke="#3b3f35" strokeWidth="8" />
      {Array.from({ length: 22 }, (_, i) => (
        <rect key={i} x="10" y={10 + i * 10.2} width="160" height="6" fill="#8d907f" opacity="0.85" />
      ))}
      <line x1="90" y1="4" x2="90" y2="236" stroke="#3b3f35" strokeWidth="6" />
    </svg>
  );
}

/** Настольная лампа. */
export function LampArt() {
  return (
    <svg viewBox="0 0 160 200" {...svg} aria-hidden>
      <ellipse cx="80" cy="186" rx="50" ry="10" fill="#151612" />
      <rect x="74" y="80" width="10" height="104" fill="#2f332a" />
      <path d="M20 86L50 20H112L142 86Z" fill="#3f5a3c" stroke="#1f2b1d" strokeWidth="3" />
      <ellipse cx="81" cy="86" rx="61" ry="8" fill="#f3e2b0" opacity="0.8" />
    </svg>
  );
}
