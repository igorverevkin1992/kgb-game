import type { Page } from '@playwright/test';
import { validateContent } from '../../src/engine/content';
import { dispatch, newCampaign, serialize, type Action, type CampaignState } from '../../src/engine/campaign';
import { readContentDir } from '../../tools/content-fs';

const report = validateContent(readContentDir().entries);
if (!report.content) throw new Error('Контент не прошёл проверку');
export const content = report.content;

/** Прогоняет действия движком (как в unit-тестах) и возвращает состояние. */
export function playActions(actions: Action[]): CampaignState {
  let state = newCampaign(content).state;
  for (const a of actions) {
    const r = dispatch(state, content, a);
    if (r.error) throw new Error(`${JSON.stringify(a)}: ${r.error}`);
    state = r.state;
  }
  return state;
}

/** Подкладывает состояние в автосохранение до загрузки страницы: игра стартует с нужного момента. */
export async function seedGame(page: Page, state: CampaignState) {
  await page.addInitScript((save) => {
    localStorage.setItem('liniya-kr:autosave', save);
  }, serialize(state));
}

export const next: Action = { type: 'advance_phase' };
export const quietWeek: Action[] = [next, next, next, { type: 'submit_report', report: 'truth' }];
