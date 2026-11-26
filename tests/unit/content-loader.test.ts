import { describe, expect, it } from 'vitest';
import { loadContent } from '../../src/content';
import { readContentDir } from '../../tools/content-fs';

describe('загрузчик контента в игре', () => {
  it('видит те же файлы, что и `npm run validate`', () => {
    const game = loadContent();
    const { entries } = readContentDir();
    const count = (folder: string) =>
      entries
        .filter((e) => e.path.startsWith(`${folder}/`))
        .reduce((n, e) => n + (Array.isArray(e.data) ? e.data.length : 1), 0);
    expect(game.targets).toHaveLength(count('targets'));
    expect(game.clues).toHaveLength(count('clues'));
    expect(game.cables).toHaveLength(count('cables'));
    expect(game.ops).toHaveLength(count('ops'));
    expect(game.campaign.acts[0]?.act).toBe(1);
  });
});
