import { describe, expect, it } from 'vitest';
import { loadContent } from '../../src/content';
import { dispatch, memoryStorage, newCampaign, weekDate, type Action, type CampaignState } from '../../src/engine/campaign';
import {
  AUTOSAVE,
  IRONMAN_FLAG,
  MAX_CHECKPOINTS,
  checkpointFor,
  listCheckpoints,
  loadSlot,
  persist,
  saveManual,
  slotInfo,
  writeCheckpoint,
} from '../../src/ui/saves';

const content = loadContent();
const quietWeek: Action[] = [{ type: 'advance_phase' }, { type: 'advance_phase' }, { type: 'advance_phase' }, { type: 'submit_report', report: 'truth' }];

function playWeeks(n: number, start = newCampaign(content).state): CampaignState[] {
  const states = [start];
  let s = start;
  for (let i = 0; i < n; i++) {
    for (const a of quietWeek) s = dispatch(s, content, a).state;
    states.push(s);
  }
  return states;
}

describe('чекпоинты', () => {
  it('создаются на неделе, с которой начинается новый календарный месяц', () => {
    const weeks = playWeeks(6); // недели 1..7: 1 окт, 8, 15, 22, 29 окт, 5 ноя, 12 ноя
    const ids = weeks.slice(1).map((s, i) => checkpointFor(weeks[i]!, s, content));
    const novemberWeek = weeks.findIndex((s) => weekDate(content, s.act, s.week)!.getUTCMonth() === 10);
    expect(ids.filter(Boolean)).toEqual([`checkpoint-a1-w${weeks[novemberWeek]!.week}`]);
  });

  it('смена фазы внутри недели чекпоинт не создаёт', () => {
    const s0 = newCampaign(content).state;
    const s1 = dispatch(s0, content, { type: 'advance_phase' }).state;
    expect(checkpointFor(s0, s1, content)).toBeNull();
  });

  it('хранится не больше MAX_CHECKPOINTS последних', () => {
    const storage = memoryStorage();
    const s = newCampaign(content).state;
    for (let i = 0; i < MAX_CHECKPOINTS + 3; i++) writeCheckpoint(storage, `checkpoint-test-${i}`, s);
    const list = listCheckpoints(storage);
    expect(list).toHaveLength(MAX_CHECKPOINTS);
    expect(list[0]).toBe('checkpoint-test-3');
    expect(storage.read('checkpoint-test-0')).toBeNull();
  });

  it('persist пишет автосейв всегда, а чекпоинт — на старте кампании и нового месяца', () => {
    const storage = memoryStorage();
    const weeks = playWeeks(6);
    persist(storage, null, weeks[0]!, content);
    for (let i = 1; i < weeks.length; i++) persist(storage, weeks[i - 1]!, weeks[i]!, content);
    expect(listCheckpoints(storage)).toHaveLength(2); // старт + ноябрь
    const info = slotInfo(storage, AUTOSAVE, content);
    expect(info?.week).toBe(weeks.at(-1)!.week);
  });
});

describe('ручные слоты и «Железный занавес»', () => {
  it('ручной слот сохраняет и загружает то же состояние', () => {
    const storage = memoryStorage();
    const s = playWeeks(2).at(-1)!;
    expect(saveManual(storage, 'manual-1', s)).toBe(true);
    const loaded = loadSlot(storage, 'manual-1', content);
    expect(loaded.ok && loaded.state).toEqual(s);
    expect(slotInfo(storage, 'manual-1', content)).toMatchObject({ week: s.week, act: 1, ironman: false });
  });

  it('в режиме «Железный занавес» нет ни ручных сохранений, ни чекпоинтов', () => {
    const storage = memoryStorage();
    const start = newCampaign(content).state;
    start.flags.push(IRONMAN_FLAG);
    const weeks = playWeeks(6, start);
    persist(storage, null, weeks[0]!, content);
    for (let i = 1; i < weeks.length; i++) persist(storage, weeks[i - 1]!, weeks[i]!, content);
    expect(listCheckpoints(storage)).toEqual([]);
    expect(saveManual(storage, 'manual-1', weeks.at(-1)!)).toBe(false);
    expect(slotInfo(storage, AUTOSAVE, content)?.ironman).toBe(true);
  });

  it('пустой слот загружается с понятной ошибкой', () => {
    expect(loadSlot(memoryStorage(), 'manual-2', content)).toEqual({ ok: false, error: 'Слот пуст' });
  });
});
