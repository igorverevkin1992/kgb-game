import { describe, expect, it } from 'vitest';
import { dictionaryKeys, translate } from '../../src/i18n';

describe('локализация', () => {
  it('в en.json те же ключи, что и в ru.json', () => {
    expect(dictionaryKeys('en').sort()).toEqual(dictionaryKeys('ru').sort());
  });

  it('подставляет параметры', () => {
    expect(translate('ru', 'desk.locked', { act: 2 })).toBe('Откроется в акте 2');
    expect(translate('en', 'desk.act', { act: 4 })).toBe('Act 4');
  });
});
