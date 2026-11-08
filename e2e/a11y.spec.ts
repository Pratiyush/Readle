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
