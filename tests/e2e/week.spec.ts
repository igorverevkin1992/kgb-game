import { expect, test } from '@playwright/test';

test('операционная неделя: четыре фазы, донесение, автосохранение', async ({ page }) => {
  await page.goto('./');
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 1');
  await expect(page.getByTestId('calendar-phase')).toHaveText('Утро');

  for (const phase of ['День', 'Вечер', 'Ночь']) {
    await page.getByTestId('advance-phase').click();
    await expect(page.getByTestId('calendar-phase')).toHaveText(phase);
  }
  await expect(page.getByTestId('advance-phase')).toHaveCount(0);
  await page.screenshot({ path: 'test-results/screens/week-night.png' });

  await page.getByTestId('report-truth').click();
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 2');
  await expect(page.getByTestId('calendar-phase')).toHaveText('Утро');

  // После перезагрузки игра продолжается с автосохранения.
  await page.reload();
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 2');

  await page.getByTestId('analyst-toggle').click();
  await expect(page.getByTestId('risk-moscow_pressure')).toContainText('20%');
  await expect(page.getByTestId('centre-trust')).toContainText('52%');
  await expect(page.getByTestId('journal')).toContainText('Кредитная история: Варгас Э.');
  await page.screenshot({ path: 'test-results/screens/analyst.png' });
  await page.keyboard.press('Escape');
  await expect(page.getByTestId('analyst')).toBeHidden();

  // ?new — начать заново.
  await page.goto('./?new');
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 1');
});

test('бездействие ведёт к отзыву в Москву', async ({ page }) => {
  await page.goto('./?new');
  for (let week = 1; week <= 12; week++) {
    for (let i = 0; i < 3; i++) await page.getByTestId('advance-phase').click();
    await page.getByTestId('report-truth').click();
  }
  await expect(page.getByTestId('ending')).toHaveAttribute('data-ending', 'recalled');
  await expect(page.getByTestId('ending')).toContainText('Отзыв в Москву');
  await page.screenshot({ path: 'test-results/screens/ending-recalled.png' });

  await page.getByTestId('new-game').click();
  await expect(page.getByTestId('calendar-week')).toHaveText('Неделя 1');
});
