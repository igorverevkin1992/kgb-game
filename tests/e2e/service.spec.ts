import { expect, test } from '@playwright/test';
import { next, openGame, playActions, quietWeek, seedGame } from './helpers';

test('Esc на столе открывает служебную папку, Esc закрывает', async ({ page }) => {
  await openGame(page, '?new');
  await page.keyboard.press('Escape');
  await expect(page.getByTestId('service-folder')).toBeVisible();
  await page.screenshot({ path: 'test-results/screens/service-saves.png' });
  await page.keyboard.press('Escape');
  await expect(page.getByTestId('service-folder')).toHaveCount(0);
  // По табличке на стене — тоже.
  await page.getByTestId('plaque').click();
  await expect(page.getByTestId('service-folder')).toBeVisible();
});

test('индикатор «Сохранено» появляется после действия', async ({ page }) => {
  await openGame(page, '?new');
  await page.getByTestId('advance-phase').click();
  await expect(page.getByTestId('save-indicator')).toHaveText('Сохранено');
});

test('ручной слот: записать, сыграть дальше, загрузить', async ({ page }) => {
  await openGame(page, '?new');
  await page.keyboard.press('Escape');
  await page.getByTestId('save-manual-1').click();
  await expect(page.getByTestId('slot-manual-1')).toContainText('Неделя 1');
  await page.keyboard.press('Escape');

  for (let i = 0; i < 3; i++) await page.getByTestId('advance-phase').click();
  await page.getByTestId('report-truth').click();
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 2');

  await page.keyboard.press('Escape');
  await page.getByTestId('load-manual-1').click();
  await expect(page.getByTestId('service-folder')).toHaveCount(0);
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 1');
});

test('чекпоинт начала месяца появляется и загружается', async ({ page }) => {
  // Неделя 5 (29 октября), ночь: следующее донесение откроет ноябрь.
  await seedGame(page, playActions([...quietWeek, ...quietWeek, ...quietWeek, ...quietWeek, next, next, next]));
  await openGame(page);
  await page.getByTestId('report-truth').click();
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 6');
  await page.keyboard.press('Escape');
  const checkpoints = page.getByTestId('checkpoints');
  await expect(checkpoints).toContainText('Неделя 6');
  await page.getByTestId('load-checkpoint-a1-w6').click();
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 6');
  await expect(page.getByTestId('calendar-phase')).toHaveText('Утро');
});

test('«Железный занавес»: ручные сохранения и чекпоинты недоступны', async ({ page }) => {
  await openGame(page, '?new');
  await page.keyboard.press('Escape');
  await page.getByTestId('new-campaign').click();
  await page.getByTestId('ironman-toggle').check();
  await page.getByTestId('new-campaign-confirm').click();
  await page.keyboard.press('Escape');
  await expect(page.getByTestId('saves')).toContainText('Железный занавес');
  await expect(page.getByTestId('save-manual-1')).toBeDisabled();
  await expect(page.getByTestId('saves')).toContainText('чекпоинтов нет');
});

test('настройки: размер текста запоминается; переключателя языка пока нет', async ({ page }) => {
  await openGame(page, '?new');
  await page.keyboard.press('Escape');
  await page.getByTestId('service-tab-settings').click();
  await expect(page.getByTestId('lang-en')).toHaveCount(0);
  await page.getByTestId('text-scale-130').click();
  await page.screenshot({ path: 'test-results/screens/service-settings.png' });

  await page.reload();
  await page.getByTestId('calendar').waitFor();
  const scale = await page.locator('main.room').evaluate((el) => getComputedStyle(el).getPropertyValue('--text-scale').trim());
  expect(scale).toBe('1.3');
  await page.getByTestId('desk-object-inbox').click();
  await page.getByTestId('inbox-item-cable_a1_w1_directive').click();
  const zoom = await page.getByTestId('document').evaluate((el) => getComputedStyle(el).zoom);
  expect(Number(zoom)).toBeCloseTo(1.3);
  await page.screenshot({ path: 'test-results/screens/doc-scaled-130.png' });
});

test('сводка аналитика показывает пороги и последствия при 100%', async ({ page }) => {
  await openGame(page, '?new');
  await page.getByTestId('analyst-toggle').click();
  await expect(page.getByTestId('risk-sog_heat')).toContainText('При 100%: нота Госдепа');
  await expect(page.getByTestId('risk-moscow_pressure')).toContainText('отзыв резидента');
  await page.screenshot({ path: 'test-results/screens/analyst-thresholds.png' });
});

test('после концовки можно загрузить чекпоинт, а не только начать заново', async ({ page }) => {
  let actions = [];
  for (let i = 0; i < 11; i++) actions.push(...quietWeek);
  actions = [...actions, next, next, next];
  await seedGame(page, playActions(actions));
  await openGame(page);
  await page.getByTestId('report-truth').click();
  await expect(page.getByTestId('ending')).toHaveAttribute('data-ending', 'recalled');
  await page.getByTestId('ending-load').click();
  await expect(page.getByTestId('service-folder')).toBeVisible();
});
