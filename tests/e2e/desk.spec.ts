import { expect, test } from '@playwright/test';

test('кабинет: в Акте I открыты 3 модуля, остальные заперты', async ({ page }) => {
  await page.goto('./');
  await expect(page.getByRole('heading', { name: 'Линия КР: Вашингтон, 1985' })).toBeVisible();
  for (const id of ['map', 'mice', 'cipher']) {
    await expect(page.getByTestId(`desk-object-${id}`)).toBeEnabled();
  }
  for (const id of ['finance', 'dialog', 'counterintel']) {
    await expect(page.getByTestId(`desk-object-${id}`)).toBeDisabled();
  }
  await page.screenshot({ path: 'test-results/screens/desk-act1.png' });
});

test('клик по объекту открывает модуль, Esc возвращает к столу; переключение < 200 мс', async ({ page }) => {
  await page.goto('./');
  for (const id of ['map', 'mice', 'cipher']) {
    // Замер внутри страницы: от клика до кадра, в котором панель уже отрисована
    // (без накладных расходов самого Playwright на ожидания и опрос DOM).
    const ms = await page.evaluate(
      (moduleId) =>
        new Promise<number>((resolve) => {
          const started = performance.now();
          document.querySelector<HTMLButtonElement>(`[data-testid="desk-object-${moduleId}"]`)!.click();
          const poll = () =>
            document.querySelector(`[data-testid="module-panel-${moduleId}"]`)
              ? requestAnimationFrame(() => resolve(performance.now() - started))
              : requestAnimationFrame(poll);
          poll();
        }),
      id,
    );
    expect(ms).toBeLessThan(200);
    await expect(page.getByTestId(`module-panel-${id}`)).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByTestId(`module-panel-${id}`)).toBeHidden();
  }
});

test('отладочные параметры ?act=4&lang=en', async ({ page }) => {
  await page.goto('./?act=4&lang=en');
  await expect(page.getByTestId('act')).toHaveText('Act 4');
  await expect(page.getByTestId('desk-object-counterintel')).toBeEnabled();
  await page.getByTestId('desk-object-counterintel').click();
  await expect(page.getByTestId('module-panel-counterintel')).toContainText('Situation console');
  await page.screenshot({ path: 'test-results/screens/desk-act4-en.png' });
});
