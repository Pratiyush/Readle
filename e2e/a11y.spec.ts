import { expect, test } from "@playwright/test";

const contrast = (fg: string, bg: string) => {
  const lum = (c: string) => {
    const [r, g, b] = (c.match(/[\d.]+/g) ?? []).map(Number).map((v) => {
      const s = v / 255;
      return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const [a, b] = [lum(fg), lum(bg)].sort((x, y) => y - x);
  return (a + 0.05) / (b + 0.05);
};

test("level chips meet text contrast (4.5:1) on every level", async ({ page }) => {
  await page.goto("./");
  await expect(page.locator(".story-card")).toHaveCount(107);
  const chips = await page.locator(".lvl").evaluateAll((els) => {
    const seen = new Map<string, [string, string]>();
    for (const el of els) {
      const cs = getComputedStyle(el);
      seen.set(el.textContent ?? "", [cs.color, cs.backgroundColor]);
    }
    return [...seen.entries()];
  });
  expect(chips.map(([l]) => l).sort()).toEqual(["A1", "A2", "B1", "B2"]);
  for (const [level, [fg, bg]] of chips) expect(contrast(fg, bg), level).toBeGreaterThanOrEqual(4.5);
});

test("200% text size: no screen scrolls sideways", async ({ page }) => {
  await page.addInitScript(() => {
    document.addEventListener("DOMContentLoaded", () => (document.documentElement.style.fontSize = "200%"));
  });
  for (const route of ["./", "./#/story/brot", "./#/words", "./#/me"]) {
    await page.goto(route);
    await page.waitForTimeout(400);
    const [scroll, width] = await page.evaluate(() => [document.documentElement.scrollWidth, document.documentElement.clientWidth]);
    expect(scroll, route).toBeLessThanOrEqual(width);
  }
});

test("word sheet is a modal dialog: focus moves in, stays in, and returns to the word (BUG-19)", async ({ page }) => {
  await page.goto("./#/story/brot");
  const gibt = page.locator("button.w", { hasText: /^gibt$/ }).first();
  await gibt.focus();
  await page.keyboard.press("Enter");
  const sheet = page.getByRole("dialog");
  await expect(sheet).toHaveAttribute("aria-modal", "true");
  await expect.poll(() => sheet.evaluate((el) => el.contains(document.activeElement))).toBe(true);
  for (let i = 0; i < 8; i++) {
    await page.keyboard.press(i % 3 === 2 ? "Shift+Tab" : "Tab");
    expect(await sheet.evaluate((el) => el.contains(document.activeElement)), `after ${i + 1} tabs`).toBe(true);
  }
  await page.keyboard.press("Escape");
  await expect(sheet).toHaveCount(0);
  await expect(gibt).toBeFocused();
});

test("filter chips say whether they are on, and none hides past the edge at 375 px (BUG-19, BUG-20)", async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto("./");
  await expect(page.locator(".story-card").first()).toBeVisible();
  await expect(page.getByRole("button", { name: "All levels" })).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "Unread" }).click();
  await expect(page.getByRole("button", { name: "Unread" })).toHaveAttribute("aria-pressed", "true");
  const outside = await page.locator(".chip").evaluateAll((els) =>
    els.filter((el) => el.getBoundingClientRect().right > innerWidth || el.getBoundingClientRect().left < 0).map((el) => el.textContent),
  );
  expect(outside).toEqual([]);
});
