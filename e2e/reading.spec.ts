// Web parity with the app: Continue reading, the first-run tip, Listen from here, and Listen only
// with a German voice.
import { expect, test } from "@playwright/test";
import { openStory, spokenTexts, stubSpeech, word } from "./helpers";

test("Listen is offered only when the device has a German voice (BUG-11)", async ({ page }) => {
  await stubSpeech(page, { german: false });
  await openStory(page, "brot");
  await expect(page.getByLabel("Show all translations")).toBeVisible();
  await expect(page.getByLabel("Listen")).toHaveCount(0);
  await page.getByLabel("Show all translations").click();
  await expect(page.getByLabel(/Listen from sentence/)).toHaveCount(0);
});

test("first run: the tap-a-word tip until the first tap, then never again", async ({ page }) => {
  await openStory(page, "brot");
  await expect(page.getByTestId("word-tip")).toBeVisible();
  await word(page, "gibt").click();
  await page.getByRole("dialog").getByRole("button", { name: "Close" }).click();
  await expect(page.getByTestId("word-tip")).toHaveCount(0);
  await openStory(page, "zwei-raeder-ein-schloss");
  await expect(page.locator(".tip")).toContainText("Tap any word for its meaning");
  await expect(page.getByTestId("word-tip")).toHaveCount(0);
});

test("continue reading: a card for the story left halfway, which reopens at that point (BUG-16)", async ({ page }) => {
  await page.goto("./");
  await expect(page.locator(".story-card").first()).toBeVisible();
  await expect(page.getByTestId("continue-card")).toHaveCount(0);

  await openStory(page, "was-der-dolmetscher-nicht-sagte");
  await page.evaluate(() => window.scrollTo(0, (document.documentElement.scrollHeight - innerHeight) * 0.7));
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage["readle.state.v1"]).progress["was-der-dolmetscher-nicht-sagte"] ?? 0)).toBeGreaterThan(2);
  await page.getByLabel("Back to stories").click();

  const card = page.getByTestId("continue-card");
  await expect(card).toContainText("Continue reading");
  await expect(card.locator("h2")).not.toBeEmpty();
  await card.click();
  await expect(page.locator(".reader h1")).toBeVisible();
  await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(100);

  await page.getByRole("button", { name: /Finish/ }).click();
  await page.goto("./");
  await expect(page.locator(".story-card").first()).toBeVisible();
  await expect(page.getByTestId("continue-card")).toHaveCount(0);
});

test("listen from here: starts at that sentence and reads on to the end", async ({ page, request }) => {
  await stubSpeech(page);
  const story = await (await request.get("./content/stories/brot.json")).json();
  const sentences = (story.sentences as { de: string }[]).map((s) => s.de);
  await openStory(page, "brot");
  await page.getByLabel("Show all translations").click();
  await page.getByLabel("Listen from sentence 5").click();
  await expect.poll(async () => (await spokenTexts(page)).length, { timeout: 5000 }).toBe(sentences.length - 4);
  expect(await spokenTexts(page)).toEqual(sentences.slice(4));
  await expect(page.getByLabel("Listen", { exact: true })).toBeVisible();
});
