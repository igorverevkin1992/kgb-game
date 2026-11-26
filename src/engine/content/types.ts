import type { Balance, Cable, Campaign, Clue, Cue, MapFile, Op, PolygraphExam, Target } from '../../schemas';

/** Сырой файл контента: путь относительно `src/content/` и разобранный JSON. */
export interface RawFile {
  path: string;
  data: unknown;
}

export interface RawBundle {
  campaign: RawFile[];
  balance: RawFile[];
  map: RawFile[];
  cues: RawFile[];
  targets: RawFile[];
  clues: RawFile[];
  cables: RawFile[];
  ops: RawFile[];
  polygraph: RawFile[];
  /** Файлы, лежащие не в той папке: о них сообщим ошибкой. */
  unknown: RawFile[];
}

/** Проверенный контент, с которым работает движок. */
export interface ContentBundle {
  campaign: Campaign;
  balance: Balance;
  /** Карта: районы и точки (`map/sites.json`). */
  map: MapFile;
  /** Приметы для карточек наблюдения на SDR (`map/cues.json`). */
  cues: Cue[];
  targets: Target[];
  clues: Clue[];
  cables: Cable[];
  ops: Op[];
  polygraph: PolygraphExam[];
}

export type IssueLevel = 'error' | 'warning';

export type RuleId =
  | 'schema'
  | 'layout'
  | 'duplicate'
  | 'refs'
  | 'unlock'
  | 'three-clue'
  | 'mice-three-clue'
  | 'softlock'
  | 'robustness'
  | 'unreachable'
  | 'sdr'
  | 'weeks'
  | 'text-length'
  | 'translation'
  | 'polygraph'
  | 'balance';

export interface Issue {
  level: IssueLevel;
  rule: RuleId;
  message: string;
  /** Файл, к которому относится проблема (если известен). */
  file?: string;
  /** Где внутри файла, например `unlock.clue_ids` или `[2].text.ru`. */
  where?: string;
}
