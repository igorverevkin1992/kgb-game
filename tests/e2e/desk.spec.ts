import { next, playActions, quietWeek, seedGame } from './helpers';
import { expect, test, type Page } from '@playwright/test';

/**
 * Замер внутри страницы: от действия до кадра, в котором нужная панель уже отрисована
 * (без накладных расходов самого Playwright на ожидания и опрос DOM).
 */
function measureSwitch(page: Page, how: 'key' | 'edge', target: string, key?: string) {
  return page.evaluate(
    ([how, target, key]) =>
      new Promise<number>((resolve) => {
        const started = performance.now();
        if (how === 'key') {
          window.dispatchEvent(new KeyboardEvent('keydown', { key: key! }));
        } else {
          document.querySelector<HTMLButtonElement>(`[data-testid="edge-${target}"]`)!.click();
        }
        const poll = () =>
          document.querySelector(`[data-testid="module-panel-${target}"]`)
            ? requestAnimationFrame(() => resolve(performance.now() - started))
            : requestAnimationFrame(poll);
        poll();
      }),
    [how, target, key] as const,
  );
}

test('кабинет: в Акте I открыты 3 модуля и почта, остальные заперты', async ({ page }) => {
  await page.goto('./?new');
  await expect(page.getByRole('heading', { name: 'Линия КР: Вашингтон, 1985' })).toBeVisible();
  for (const id of ['map', 'mice', 'cipher', 'inbox']) {
    await expect(page.getByTestId(`desk-object-${id}`)).toBeEnabled();
  }
  for (const id of ['finance', 'dialog', 'counterintel']) {
    await expect(page.getByTestId(`desk-object-${id}`)).toBeDisabled();
  }
  await expect(page.getByTestId('inbox-unread')).toHaveText('3');
  await page.screenshot({ path: 'test-results/screens/desk-act1.png' });
});

test('приёмка шага 3: переключение модулей напрямую быстрее 0,2 с', async ({ page }) => {
  await page.goto('./?new&act=4');
  await page.getByTestId('desk-object-map').click();
  await expect(page.getByTestId('module-panel-map')).toBeVisible();

  // Клавишами 1–7 прямо из открытого модуля, без возврата к столу.
  const byKey: [string, string][] = [
    ['mice', '2'],
    ['cipher', '3'],
    ['finance', '4'],
    ['dialog', '5'],
  ];
  for (const [id, key] of byKey) {
    const ms = await measureSwitch(page, 'key', id, key);
    expect(ms, `${id}: ${ms.toFixed(0)} мс`).toBeLessThan(200);
    await expect(page.getByTestId(`edge-${id}`)).toHaveAttribute('aria-current', 'true');
  }
  // Кликом по предметам на краю стола.
  for (const id of ['counterintel', 'map', 'inbox', 'mice']) {
    const ms = await measureSwitch(page, 'edge', id);
    expect(ms, `${id}: ${ms.toFixed(0)} мс`).toBeLessThan(200);
  }
  await page.keyboard.press('Escape');
  await expect(page.getByTestId('module-panel-mice')).toBeHidden();
});

test('запертый модуль не открывается ни кликом, ни клавишей', async ({ page }) => {
  await page.goto('./?new');
  await expect(page.getByTestId('calendar')).toBeVisible();
  await page.keyboard.press('4');
  await expect(page.getByTestId('module-panel-finance')).toHaveCount(0);
  await page.keyboard.press('1');
  await expect(page.getByTestId('edge-finance')).toBeDisabled();
});

test('лоток входящих: документы трёх видов, прочитанное снимает счётчик', async ({ page }) => {
  await page.goto('./?new');
  await page.getByTestId('desk-object-inbox').click();
  await expect(page.getByTestId('inbox-list').getByRole('button')).toHaveCount(3);

  await page.getByTestId('inbox-item-cable_a1_w1_post_clipping').click();
  await expect(page.getByTestId('document')).toHaveAttribute('data-kind', 'press_clipping');
  await expect(page.getByTestId('document')).toContainText('Монтескьё');
  await page.screenshot({ path: 'test-results/screens/doc-clipping.png' });

  await page.getByTestId('inbox-item-cable_a1_w1_directive').click();
  await expect(page.getByTestId('document')).toHaveAttribute('data-kind', 'directive');
  await expect(page.getByTestId('document')).toContainText('Секретно');
  await page.screenshot({ path: 'test-results/screens/doc-directive.png' });

  await page.keyboard.press('Escape');
  await expect(page.getByTestId('inbox-unread')).toHaveText('1');
});

test('доска MICE показывает установленные цели', async ({ page }) => {
  await page.goto('./?new');
  await expect(page.getByTestId('calendar')).toBeVisible();
  await page.keyboard.press('2');
  await expect(page.getByTestId('dossiers')).toContainText('Неустановленных целей: 2');
  await page.screenshot({ path: 'test-results/screens/module-mice.png' });
});

test('сцена масштабируется под окно и сохраняет пропорции 16:9', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('./?new');
  const box = await page.getByTestId('stage').boundingBox();
  expect(box!.width).toBeCloseTo(1280, 0);
  expect(box!.height).toBeCloseTo(720, 0);
  expect(box!.x).toBeCloseTo(0, 0);
  expect(box!.y).toBeCloseTo(40, 0); // поля сверху и снизу по 40 px
});

test('отладочные параметры ?act=4&lang=en', async ({ page }) => {
  await page.goto('./?new&act=4&lang=en');
  await expect(page.getByTestId('act')).toHaveText('Act 4');
  await expect(page.getByTestId('desk-object-counterintel')).toBeEnabled();
  await page.getByTestId('desk-object-counterintel').click();
  await expect(page.getByTestId('module-panel-counterintel')).toContainText('Situation console');
  await page.screenshot({ path: 'test-results/screens/desk-act4-en.png' });
});

test('доска MICE: досье установленных целей с гипотезами и подтверждёнными осями', async ({ page }) => {
  const state = playActions([
    ...quietWeek,
    ...quietWeek,
    next,
    { type: 'plan_op', op_id: 'op_a1_recon_first_virginia' },
    { type: 'plan_op', op_id: 'op_a1_recon_potomac_cellar' },
    next,
    { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'continue' },
    { type: 'resolve_op', op_id: 'op_a1_recon_potomac_cellar', decision: 'continue' },
  ]);
  await seedGame(page, state);
  await page.goto('./');
  // Отметка наружки на карте: пропущенный хвост поднял SOG Heat выше 20%.
  await expect(page.locator('[data-testid="desk-object-map"] [data-sog-mark]')).toHaveCount(1);
  await page.keyboard.press('2');
  await expect(page.getByTestId('dossier-tar_vargas_ellen')).toContainText('Элен Варгас');
  await expect(page.getByTestId('dossier-tar_calloway_martin')).toContainText('3 улики');
  await page.screenshot({ path: 'test-results/screens/module-mice-dossiers.png' });
});
