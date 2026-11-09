import { expect, test } from "@playwright/test";
import { openStory, played, spoken, stubAudio, stubSpeech, word } from "./helpers";

test.describe("reader", () => {
  test("tap a word: meaning, inflection note, save, close", async ({ page }) => {
    await openStory(page, "brot");
    await word(page, "gibt").click();
    const sheet = page.getByRole("dialog");
    await expect(sheet.locator(".headword")).toContainText("geben");
    await expect(sheet).toContainText("gibt is a form of geben.");
    await expect(sheet).toContainText("to give");
    await sheet.getByRole("button", { name: /Save to my words/ }).click();
    await expect(sheet.getByRole("button", { name: /Saved to your words/ })).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(sheet).toBeHidden();
    await expect(word(page, "gibt")).toHaveClass(/w-saved/);
  });

  test("names are not glossed through a random tail", async ({ page }) => {
    await openStory(page, "brot");
    await word(page, "Deutschland").click();
    await expect(page.getByRole("dialog")).toContainText("No dictionary entry");
  });

  test("sentence and whole-story translations", async ({ page }) => {
    await openStory(page, "brot");
    await page.getByLabel("Translate sentence 1").click();
    await expect(page.locator(".translation")).toHaveCount(1);
    await expect(page.locator(".translation .tr-text")).toHaveText("In Germany, bread is very important.");
    await page.getByLabel("Show all translations").click();
    await expect(page.locator(".translation")).toHaveCount(8);
  });

  test("punctuation never wraps away from its word", async ({ page }) => {
    await openStory(page, "was-der-dolmetscher-nicht-sagte");
    const split = await page.locator(".story-text .nw").evaluateAll(
      (els) => els.filter((e) => e.getClientRects().length > 1).map((e) => e.textContent),
    );
    expect(split).toEqual([]);
    // every sentence's ⇄ sits on the same line as the end of its sentence
    const orphans = await page.locator(".tr-btn").evaluateAll((btns) =>
      btns.filter((b) => {
        const prev = [...b.closest(".sentence")!.querySelectorAll("button.w")].at(-1)!;
        return Math.abs(prev.getBoundingClientRect().top - b.getBoundingClientRect().top) > 8;
      }).length,
    );
    expect(orphans).toBe(0);
  });

  test("text size cycles", async ({ page }) => {
    await openStory(page, "brot");
    const scale = () => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--reader-scale"));
    const before = await scale();
    await page.getByLabel("Text size").click();
    expect(await scale()).not.toBe(before);
  });

  test("listening reads every sentence, and stops when you leave", async ({ page }) => {
    await stubSpeech(page);
    await openStory(page, "brot");
    await page.getByLabel("Listen").click();
    await expect(page.getByLabel("Stop")).toBeVisible();
    await expect(page.locator(".sentence.playing")).toHaveCount(1);
    await expect.poll(() => spoken(page), { timeout: 5000 }).toBe(8);
    await expect(page.getByLabel("Listen")).toBeVisible();

    await page.getByLabel("Listen").click();
    await expect.poll(() => spoken(page)).toBeGreaterThan(8);
    await page.getByLabel("Back to stories").click();
    const atLeave = await spoken(page);
    await page.waitForTimeout(800);
    expect(await spoken(page)).toBe(atLeave);
  });

  test("tapping a word plays its recorded clip; words without one use the device voice", async ({ page }) => {
    await stubAudio(page);
    await stubSpeech(page);
    await openStory(page, "brot");
    await word(page, "gibt").click();
    await expect.poll(() => played(page)).toHaveLength(1);
    const [clip] = await played(page);
    expect(clip).toMatch(/\/content\/audio\/de\.geben\.v\.mp3$/);
    const res = await page.request.get(clip);
    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("audio/mpeg");
    expect((await res.body()).length).toBeGreaterThan(1000);

    await page.getByRole("dialog").getByRole("button", { name: "Pronounce" }).click();
    await expect.poll(() => played(page)).toHaveLength(2);

    await page.keyboard.press("Escape");
    await word(page, "Deutschland").click(); // a name: no entry, no clip
    await expect.poll(() => spoken(page)).toBe(1);
    expect(await played(page)).toHaveLength(2);
  });

  test("'Say words when tapped' off: tapping stays silent", async ({ page }) => {
    await stubAudio(page);
    await page.goto("./#/me");
    await page.getByLabel("Say words when tapped").uncheck();
    await openStory(page, "brot");
    await word(page, "gibt").click();
    await expect(page.getByRole("dialog")).toBeVisible();
    await page.waitForTimeout(300);
    expect(await played(page)).toHaveLength(0);
  });
});
