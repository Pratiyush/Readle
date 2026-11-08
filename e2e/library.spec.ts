import { expect, test } from "@playwright/test";

test.describe("library", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("./");
    await expect(page.locator(".story-card")).toHaveCount(107);
  });

  test("shows the story of the day and filters by level, collection and unread", async ({ page }) => {
    await expect(page.locator(".daily h2")).not.toBeEmpty();
    await page.getByRole("button", { name: "A1", exact: true }).click();
    await expect(page.locator(".story-card")).toHaveCount(30);
    await page.getByRole("button", { name: "Facts" }).click();
    const n = await page.locator(".story-card").count();
    expect(n).toBeGreaterThan(0);
    expect(n).toBeLessThan(30);
    await page.getByRole("button", { name: "All levels" }).click();
    await page.getByRole("button", { name: "All", exact: true }).click();
    await page.getByRole("button", { name: "Unread" }).click();
    await expect(page.locator(".story-card")).toHaveCount(107);
  });

  test("searches German titles and English teasers", async ({ page }) => {
    const search = page.getByPlaceholder("Search stories…");
    await search.fill("bread");
    await expect(page.locator(".story-card")).toHaveCount(3);
    await search.fill("Brot");
    await expect(page.locator(".story-card")).toHaveCount(3);
    await search.fill("zzzz");
    await expect(page.getByText("No stories match these filters.")).toBeVisible();
  });

  test("coming back from a story keeps the list position and filters", async ({ page }) => {
    await page.getByRole("button", { name: "Facts" }).click();
    await page.evaluate(() => window.scrollTo(0, 1200));
    await page.waitForFunction(() => window.scrollY > 1000);
    const y = await page.evaluate(() => window.scrollY);
    await page.locator(".story-card").nth(8).click();
    await expect(page.locator(".reader h1")).toBeVisible();
    await page.getByLabel("Back to stories").click();
    await expect(page.getByRole("button", { name: "Facts" })).toHaveClass(/on/);
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(y);
  });
});
