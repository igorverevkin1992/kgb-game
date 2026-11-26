import { expect, test } from '@playwright/test';
import { GOOD_ROUTE, next, openGame, playActions, quietWeek, seedGame } from './helpers';

const TAIL = 'light_blue_ford_ltd';

test('день: маршрут SDR прокладывается кликами по карте и списку', async ({ page }) => {
  await seedGame(page, playActions([...quietWeek, next])); // 2-я неделя, день
  await openGame(page);
  await page.getByTestId('desk-object-map').click();
  await expect(page.getByTestId('zone-circle')).toBeVisible();

  await page.getByTestId('op-op_a1_recon_first_virginia').click();
  await page.getByTestId('site-site_peoples_drug_connecticut').click(); // по булавке на карте
  await page.getByTestId('site-site_georgetown_post_office').click();
  await page.getByTestId('stop-site_lee_highway_cleaners').click(); // из списка
  await expect(page.getByTestId('route-builder')).toContainText('Химчистка на Ли-хайвей');
  await expect(page.getByTestId('route-warnings')).toHaveCount(0);
  await page.screenshot({ path: 'test-results/screens/map-planning.png' });

  await page.getByTestId('confirm-route').click();
  await expect(page.getByTestId('planned-ops')).toContainText('Осмотр отделения «Ферст Вирджиния бэнк»');
  await expect(page.getByTestId('planned-ops')).toContainText('Аптека «Пиплс драг» → Почтовое отделение Джорджтауна → Химчистка на Ли-хайвей');
});

test('день: слабый маршрут в одном районе и выезд за 25 миль вызывают предупреждения', async ({ page }) => {
  await seedGame(page, playActions([...quietWeek, next]));
  await openGame(page);
  await page.keyboard.press('1');
  await page.getByTestId('op-op_a1_recon_first_virginia').click();
  for (const id of ['site_georgetown_post_office', 'site_wisconsin_bookshop', 'site_leesburg_antiques']) {
    await page.getByTestId(`stop-${id}`).click();
  }
  const warnings = page.getByTestId('route-warnings');
  await expect(warnings).toContainText('Точки только в 2 район');
  await expect(warnings).toContainText('за 25 милями');
  await page.screenshot({ path: 'test-results/screens/map-warnings.png' });
});

test('вечер: на правильном маршруте хвост мелькает дважды — сворачиваем на легенду', async ({ page }) => {
  await seedGame(
    page,
    playActions([...quietWeek, next, { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE }, next]),
  );
  await openGame(page);
  await page.keyboard.press('1');
  await page.getByTestId('depart-op_a1_recon_first_virginia').click();
  await expect(page.getByTestId('sdr-stop-1')).toBeVisible();
  await page.getByTestId('sdr-next').click();
  await page.getByTestId('sdr-next').click();
  await expect(page.getByTestId('sdr-stop-3')).toBeVisible();
  await expect(page.locator(`[data-cue="${TAIL}"]`)).toHaveCount(2);
  await page.screenshot({ path: 'test-results/screens/map-sdr-tail.png' });

  // «Вердикт»: блокнот сравнения, обводим повторившуюся машину и сворачиваем.
  await page.getByTestId('sdr-to-verdict').click();
  const notebook = page.getByTestId('sdr-notebook');
  await expect(notebook.locator(`[data-cue="${TAIL}"]`)).toHaveCount(2);
  const first = notebook.locator(`[data-cue="${TAIL}"]`).first();
  await first.click();
  await expect(first).toHaveAttribute('aria-pressed', 'true');
  await page.screenshot({ path: 'test-results/screens/map-sdr-verdict.png' });
  await page.getByTestId('sdr-verdict-tail').click();
  await expect(page.getByTestId('sdr-result')).toHaveAttribute('data-result', 'aborted');
  await page.getByTestId('sdr-done').click();
  await expect(page.getByTestId('sdr-run')).toHaveCount(0);
});

test('свернуть можно и посреди маршрута, не дожидаясь вердикта', async ({ page }) => {
  await seedGame(
    page,
    playActions([...quietWeek, next, { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE }, next]),
  );
  await openGame(page);
  await page.keyboard.press('1');
  await page.getByTestId('depart-op_a1_recon_first_virginia').click();
  await page.getByTestId('sdr-abort').click();
  await expect(page.getByTestId('sdr-result')).toHaveAttribute('data-result', 'aborted');
});

test('вечер: чистый выезд к бару приносит улики и открывает цель', async ({ page }) => {
  await seedGame(
    page,
    playActions([...quietWeek, ...quietWeek, next, { type: 'plan_op', op_id: 'op_a1_recon_potomac_cellar', route: GOOD_ROUTE }, next]),
  );
  await openGame(page);
  await page.keyboard.press('1');
  await page.getByTestId('depart-op_a1_recon_potomac_cellar').click();
  await page.getByTestId('sdr-next').click();
  await page.getByTestId('sdr-next').click();
  await page.getByTestId('sdr-to-verdict').click();
  await page.getByTestId('sdr-verdict-clean').click();
  const result = page.getByTestId('sdr-result');
  await expect(result).toHaveAttribute('data-result', 'done');
  await expect(result).toContainText('«Они держат меня за официанта»');
  await expect(result).toContainText('Цель установлена: Мартин Кэллоуэй');
  await page.screenshot({ path: 'test-results/screens/map-sdr-result.png' });

  // После выезда вечер можно закончить: операций не осталось.
  await page.getByTestId('sdr-done').click();
  await page.keyboard.press('Escape');
  await page.getByTestId('advance-phase').click();
  await expect(page.getByTestId('calendar-phase')).toHaveText('Ночь');
});
