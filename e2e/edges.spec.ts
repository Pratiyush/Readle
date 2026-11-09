// Edge cases in the browser (docs/test-plan.md): damaged storage, everything read, level switches.
import { expect, test } from "@playwright/test";

const seed = (state: unknown) => (s: string) => localStorage.setItem("readle.state.v1", s);

test("a damaged saved word doesn't blank the app (BUG-37)", async ({ page }) => {
  const state = { words: { broken: "not a word", nocard: { key: "nocard", word: "x" } }, read: { brot: 7 } };
  await page.addInitScript(seed(state), JSON.stringify(state));
  await page.goto("./");
  await expect(page.locator(".story-card")).toHaveCount(107);
  await page.getByRole("link", { name: /Words/ }).click();
  await expect(page.locator("h1")).toBeVisible();
});

test("every story read: the story of the day still offers one", async ({ page, request }) => {
  const lib = (await (await request.get("./content/stories.json")).json()) as { id: string }[];
  const state = { read: Object.fromEntries(lib.map((s) => [s.id, "2026-11-01"])) };
  await page.addInitScript(seed(state), JSON.stringify(state));
  await page.goto("./");
  await expect(page.locator(".daily h2")).not.toBeEmpty();
  await page.getByRole("button", { name: "Unread" }).click();
  await expect(page.getByText("No stories match these filters.")).toBeVisible();
});

test("switching level mid-session: list and story of the day follow at once", async ({ page }) => {
  await page.goto("./");
  await expect(page.locator(".daily .lvl")).toHaveText("A1"); // all levels, in sequence
  for (const level of ["B2", "A2", "B1"]) {
    await page.getByRole("button", { name: level, exact: true }).click();
    await expect(page.locator(".daily .lvl")).toHaveText(level);
    const levels = await page.locator(".story-card .lvl").allTextContents();
    expect(new Set(levels)).toEqual(new Set([level]));
  }
});
