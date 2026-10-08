import { test, expect } from '@playwright/test';

const email = process.env.E2E_EMAIL;
const password = process.env.E2E_PASSWORD;

test('test account can read the home and MomentLoop core paths', async ({ page }) => {
  if (!email || !password) {
    throw new Error('Set E2E_EMAIL and E2E_PASSWORD before running the read-only E2E test.');
  }

  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await page.getByRole('button', { name: '이메일로 로그인' }).first().click();
  const loginInputs = page.locator('input[data-semantics-role="text-field"]');
  await expect(loginInputs).toHaveCount(2);
  const emailInput = loginInputs.nth(0);
  const passwordInput = loginInputs.nth(1);
  await emailInput.click();
  await expect(emailInput).toBeFocused();
  await page.waitForTimeout(300);
  await emailInput.pressSequentially(email);
  await passwordInput.click();
  await expect(passwordInput).toBeFocused();
  await page.waitForTimeout(300);
  await passwordInput.pressSequentially(password);
  await expect(emailInput).toHaveValue(email);
  await expect(passwordInput).toHaveValue(password);
  await page.getByRole('button', { name: '로그인', exact: true }).first().click();

  await expect(page.getByRole('tab', { name: '홈', exact: true })).toBeVisible({ timeout: 30_000 });
  await expect(page.getByRole('tab', { name: 'MomentLoop', exact: true })).toBeVisible();

  await page.getByRole('tab', { name: 'MomentLoop', exact: true }).click();
  await expect(page.getByRole('tab', { name: 'MomentLoop', exact: true })).toHaveAttribute('aria-selected', 'true', { timeout: 15_000 });

  await page.reload();
  await expect(page.getByRole('tab', { name: '홈', exact: true })).toHaveAttribute('aria-selected', 'true', { timeout: 30_000 });
  await expect(page.getByRole('tab', { name: 'MomentLoop', exact: true })).toBeVisible();
});
