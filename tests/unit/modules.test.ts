import { describe, expect, it } from 'vitest';
import { DESK_MODULES, parseAct, unlockedModules } from '../../src/engine/modules';

describe('модули рабочего стола', () => {
  it('всего шесть модулей, id уникальны', () => {
    const ids = DESK_MODULES.map((m) => m.id);
    expect(ids).toHaveLength(6);
    expect(new Set(ids).size).toBe(6);
  });

  it('в Акте I доступны только карта SDR, доска MICE и шифроузел (защита от перегрузки)', () => {
    expect(unlockedModules(1).map((m) => m.id)).toEqual(['map', 'mice', 'cipher']);
  });

  it('с каждым актом модули только добавляются', () => {
    for (let act = 2; act <= 4; act++) {
      const prev = unlockedModules(parseAct(String(act - 1))).map((m) => m.id);
      const curr = unlockedModules(parseAct(String(act))).map((m) => m.id);
      expect(curr).toEqual(expect.arrayContaining(prev));
    }
    expect(unlockedModules(4)).toHaveLength(6);
  });

  it('parseAct отбрасывает мусор', () => {
    expect(parseAct('3')).toBe(3);
    expect(parseAct('9')).toBe(1);
    expect(parseAct(null)).toBe(1);
  });
});
