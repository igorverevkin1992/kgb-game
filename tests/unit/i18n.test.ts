import { describe, expect, it } from 'vitest';
import { loadContent } from '../../src/content';
import { dispatch, newCampaign, type Action } from '../../src/engine/campaign';
import { dictionaryKeys, translate, type I18nKey } from '../../src/i18n';
import { formatUsd } from '../../src/ui/format';

/** Латиница, которой не место в русской версии: без плейсхолдеров {x} и римских цифр (Акт II). */
function latin(text: string): string[] {
  const cleaned = text.replace(/\{\w+\}/g, '').replace(/\b[IVX]+\b/g, '');
  return cleaned.match(/[A-Za-z]+/g) ?? [];
}

describe('русская версия', () => {
  it('в строках интерфейса нет латиницы', () => {
    const bad = dictionaryKeys('ru')
      .map((k) => [k, translate('ru', k as I18nKey)] as const)
      .filter(([, v]) => latin(v).length > 0);
    expect(bad).toEqual([]);
  });

  it('в русских текстах контента нет латиницы', () => {
    const content = loadContent();
    const bad: string[] = [];
    const walk = (v: unknown, path: string) => {
      if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${path}[${i}]`));
      else if (v && typeof v === 'object') {
        const o = v as Record<string, unknown>;
        if (typeof o.ru === 'string') {
          if (latin(o.ru).length) bad.push(`${path}: ${o.ru}`);
          return;
        }
        for (const [k, x] of Object.entries(o)) walk(x, `${path}.${k}`);
      }
    };
    walk(content, 'content');
    expect(bad).toEqual([]);
  });

  it('сообщения движка, которые видит игрок, — по-русски, без внутренних id', () => {
    const content = loadContent();
    const { state } = newCampaign(content);
    const attempts: Action[] = [
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: [] },
      { type: 'recruitment', target_id: 'tar_vargas_ellen', result: 'success' },
      { type: 'submit_report', report: 'truth' },
      { type: 'read_cable', cable_id: 'cable_a1_w3_intercept' },
    ];
    for (const a of attempts) {
      const { error } = dispatch(state, content, a);
      expect(error).toBeTruthy();
      expect(latin(error!), error).toEqual([]);
    }
  });

  it('суммы — словами, по-русски', () => {
    expect(formatUsd(40000, 'ru')).toBe('40 000 долларов');
    expect(formatUsd(21, 'ru')).toBe('21 доллар');
    expect(formatUsd(3, 'ru')).toBe('3 доллара');
    expect(formatUsd(12, 'ru')).toBe('12 долларов');
  });

  it('подставляет параметры', () => {
    expect(translate('ru', 'desk.locked', { act: 2 })).toBe('Откроется в акте 2');
  });
});
