import { expect, test } from "@playwright/test";

test("works offline after a single visit", async ({ page, context }) => {
  await page.goto("./");
  await expect(page.locator(".story-card")).toHaveCount(107);
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await new Promise((r) => navigator.serviceWorker.addEventListener("controllerchange", r, { once: true }));
  });
  await page.goto("./#/story/brot");
  await expect(page.locator(".reader h1")).toHaveText("Brot ist hier wichtig");

  await context.setOffline(true);
  await page.goto("./");
  await page.reload();
  await expect(page.locator(".story-card")).toHaveCount(107);
  await page.goto("./#/story/brot");
  await expect(page.locator(".reader h1")).toHaveText("Brot ist hier wichtig");
  await page.goto("./#/story/markt");
  await expect(page.getByText("This story couldn't be loaded.")).toBeVisible();
});
