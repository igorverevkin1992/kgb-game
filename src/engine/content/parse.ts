import type { z } from 'zod';
import { Balance, Cable, CableFile, Campaign, Clue, ClueFile, CueFile, MapFile, Op, PolygraphExam, Target } from '../../schemas';
import type { Cue } from '../../schemas';
import type { ContentBundle, Issue, RawBundle, RawFile } from './types';

const FOLDERS = ['targets', 'clues', 'cables', 'ops', 'polygraph'] as const;

/** Файлы, которые существуют в одном экземпляре. */
const SINGLE_FILES: Record<string, 'campaign' | 'balance' | 'map' | 'cues'> = {
  'campaign.json': 'campaign',
  'balance.json': 'balance',
  'map/sites.json': 'map',
  'map/cues.json': 'cues',
};

/** Раскладывает файлы по типам контента по их пути (`targets/x.json`, `campaign.json` и т. д.). */
export function bundleFromEntries(entries: RawFile[]): RawBundle {
  const raw: RawBundle = { campaign: [], balance: [], map: [], cues: [], targets: [], clues: [], cables: [], ops: [], polygraph: [], unknown: [] };
  for (const entry of entries) {
    const path = entry.path.replace(/\\/g, '/').replace(/^\.\//, '');
    const file = { ...entry, path };
    const single = SINGLE_FILES[path];
    if (single) {
      raw[single].push(file);
      continue;
    }
    const folder = FOLDERS.find((f) => path.startsWith(`${f}/`));
    (folder ? raw[folder] : raw.unknown).push(file);
  }
  return raw;
}

/** Где-то в файле: `[3].text.ru` для массивов, `unlock.clue_ids` для объектов. */
function formatPath(path: PropertyKey[], prefix = ''): string {
  let out = prefix;
  for (const p of path) out += typeof p === 'number' ? `[${p}]` : out ? `.${String(p)}` : String(p);
  return out || '(весь файл)';
}

function parseFile<S extends z.ZodType>(schema: S, file: RawFile, issues: Issue[], prefix = ''): z.infer<S> | null {
  const result = schema.safeParse(file.data);
  if (result.success) return result.data;
  for (const issue of result.error.issues) {
    issues.push({ level: 'error', rule: 'schema', file: file.path, where: formatPath(issue.path, prefix), message: issue.message });
  }
  return null;
}

export interface ParseResult {
  bundle: ContentBundle | null;
  issues: Issue[];
  /** id сущности → файл, в котором она описана (для понятных сообщений об ошибках). */
  fileOf: Map<string, string>;
}

/** Проверяет каждый файл по Zod-схеме и собирает контент. Связи между файлами проверяет `rules.ts`. */
export function parseBundle(raw: RawBundle): ParseResult {
  const issues: Issue[] = [];
  const fileOf = new Map<string, string>();

  for (const f of raw.unknown) {
    issues.push({
      level: 'error',
      rule: 'layout',
      file: f.path,
      message: 'Файл лежит вне известных папок. Допустимо: campaign.json, balance.json, map/sites.json, map/cues.json, targets/, clues/, cables/, ops/, polygraph/',
    });
  }

  const register = (id: string, kind: string, path: string) => {
    const prev = fileOf.get(id);
    if (prev) {
      issues.push({ level: 'error', rule: 'duplicate', file: path, message: `${kind} «${id}» уже описан(а) в файле ${prev}` });
    } else {
      fileOf.set(id, path);
    }
  };

  let campaign: Campaign | null = null;
  if (raw.campaign.length === 0) {
    issues.push({ level: 'error', rule: 'layout', message: 'Нет файла campaign.json со структурой актов' });
  } else {
    const first = raw.campaign[0];
    if (first) campaign = parseFile(Campaign, first, issues);
  }

  let balance: Balance | null = null;
  if (raw.balance.length === 0) {
    issues.push({ level: 'error', rule: 'layout', message: 'Нет файла balance.json с числами баланса' });
  } else {
    const first = raw.balance[0];
    if (first) balance = parseFile(Balance, first, issues);
  }

  const single = <T,>(files: RawFile[], name: string, schema: Parameters<typeof parseFile>[0]): T | null => {
    const first = files[0];
    if (!first) {
      issues.push({ level: 'error', rule: 'layout', message: `Нет файла ${name}` });
      return null;
    }
    return parseFile(schema, first, issues) as T | null;
  };
  const map = single<MapFile>(raw.map, 'map/sites.json с точками карты', MapFile);
  const cues = single<Cue[]>(raw.cues, 'map/cues.json с приметами для SDR', CueFile);
  if (map) for (const site of map.sites) register(site.site_id, 'Точка карты', 'map/sites.json');
  if (cues) for (const cue of cues) register(cue.tag, 'Примета', 'map/cues.json');

  const targets: Target[] = [];
  for (const f of raw.targets) {
    const t = parseFile(Target, f, issues);
    if (t) {
      register(t.target_id, 'Цель', f.path);
      targets.push(t);
    }
  }

  const clues: Clue[] = [];
  for (const f of raw.clues) {
    if (!Array.isArray(f.data)) {
      parseFile(ClueFile, f, issues);
      continue;
    }
    f.data.forEach((item, i) => {
      const c = parseFile(Clue, { path: f.path, data: item }, issues, `[${i}]`);
      if (c) {
        register(c.clue_id, 'Улика', f.path);
        clues.push(c);
      }
    });
  }

  const cables: Cable[] = [];
  for (const f of raw.cables) {
    if (!Array.isArray(f.data)) {
      parseFile(CableFile, f, issues);
      continue;
    }
    f.data.forEach((item, i) => {
      const c = parseFile(Cable, { path: f.path, data: item }, issues, `[${i}]`);
      if (c) {
        register(c.cable_id, 'Депеша', f.path);
        cables.push(c);
      }
    });
  }

  const ops: Op[] = [];
  for (const f of raw.ops) {
    const o = parseFile(Op, f, issues);
    if (o) {
      register(o.op_id, 'Операция', f.path);
      ops.push(o);
    }
  }

  const polygraph: PolygraphExam[] = [];
  for (const f of raw.polygraph) {
    const p = parseFile(PolygraphExam, f, issues);
    if (p) {
      register(p.exam_id, 'Экзамен', f.path);
      polygraph.push(p);
    }
  }

  const bundle =
    campaign && balance && map && cues ? { campaign, balance, map, cues, targets, clues, cables, ops, polygraph } : null;
  return { bundle, issues, fileOf };
}
