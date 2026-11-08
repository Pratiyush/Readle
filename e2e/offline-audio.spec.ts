import { expect, test } from "@playwright/test";
import { openStory, spoken, stubSpeech, word } from "./helpers";

/** Record whether each real play() resolved (clip played) or rejected (fell back). */
async function watchPlays(page: import("@playwright/test").Page) {
  await page.addInitScript(() => {
    const w = window as unknown as { __plays: string[] };
    w.__plays = [];
    const orig = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      const p = orig.call(this);
      p.then(() => w.__plays.push("ok"), (e: Error) => w.__plays.push(`err:${e.name}`));
      return p;
    };
  });
}
const plays = (page: import("@playwright/test").Page) =>
  page.evaluate(() => (window as unknown as { __plays: string[] }).__plays);

test("a word clip heard once still plays offline", async ({ page, context }) => {
  await watchPlays(page);
  await stubSpeech(page);
  await page.goto("./");
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await new Promise((r) => navigator.serviceWorker.addEventListener("controllerchange", r, { once: true }));
  });
  await openStory(page, "brot");
  await word(page, "gibt").click();
  await expect.poll(() => plays(page)).toEqual(["ok"]);
  await page.waitForTimeout(1500);

  await context.setOffline(true);
  await page.reload();
  await expect(page.locator(".reader h1")).toBeVisible();
  await word(page, "gibt").click();
  await expect.poll(() => plays(page), { timeout: 8000 }).toHaveLength(1);
  expect(await plays(page)).toEqual(["ok"]);
  expect(await spoken(page)).toBe(0);
});
