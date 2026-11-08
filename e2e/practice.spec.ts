import { expect, test } from "@playwright/test";
import { openStory, word } from "./helpers";

test("finish a story, take the quiz, see progress", async ({ page }) => {
  await openStory(page, "brot");
  await page.getByRole("button", { name: "Finish & take the quiz" }).click();
  await expect(page).toHaveURL(/#\/story\/brot\/quiz$/);
  for (let i = 0; i < 10; i++) {
    const options = page.locator(".option");
    if (!(await options.count())) break;
    await options.first().click();
    await expect(page.locator(".option.right")).toHaveCount(1);
    await page.locator(".feedback .btn").click();
  }
  await expect(page.getByRole("heading", { name: "Gut gemacht!" })).toBeVisible();
  await expect(page.locator(".stat b").first()).toHaveText(/^\d+%$/);
  await page.getByRole("link", { name: "Next story" }).click();
  await expect(page.locator(".story-card", { hasText: "Brot ist hier wichtig" })).toContainText("✓ Read");
  await expect(page.locator(".streak-pill")).toContainText("1");
  await page.getByRole("link", { name: /Progress/ }).click();
  await expect(page.locator(".level-row").first()).toContainText("1/30");
});

test("quiz word questions never mix verbs and nouns in the options", async ({ page }) => {
  await openStory(page, "brot");
  await page.getByRole("button", { name: "Finish & take the quiz" }).click();
  while ((await page.locator(".eyebrow").textContent())?.includes("word")) {
    const prompt = (await page.locator(".quiz-word").textContent()) ?? "";
    const options = await page.locator(".option").allTextContents();
    const verbs = options.filter((o) => o.startsWith("to ")).length;
    if (/^(der|die|das) /.test(prompt)) expect(verbs, options.join(" / ")).toBe(0);
    await page.locator(".option").first().click();
    await page.locator(".feedback .btn").click();
  }
});

test("save a word, then review it with spaced repetition", async ({ page }) => {
  await openStory(page, "brot");
  await word(page, "gibt").click();
  await page.getByRole("button", { name: /Save to my words/ }).click();
  await page.keyboard.press("Escape");
  await page.getByLabel("Back to stories").click();
  await expect(page.locator(".tab .badge")).toHaveText("1");
  await page.getByRole("link", { name: /Words/ }).click();
  await expect(page.locator(".word-row")).toContainText("geben");
  await page.getByRole("link", { name: "Practice" }).click();
  await expect(page.locator(".fc-word")).toHaveText("geben");
  await page.getByRole("button", { name: "Show answer" }).click();
  await expect(page.locator(".fc-gloss")).toContainText("to give");
  await page.getByRole("button", { name: "Knew it" }).click();
  await expect(page.getByRole("heading", { name: "Session complete" })).toBeVisible();
  const card = await page.evaluate(() => JSON.parse(localStorage.getItem("readle.state.v1")!).words["de.geben.v"].card);
  expect(card.box).toBe(1);
  await page.getByRole("link", { name: "Back to words" }).click();
  await expect(page.locator(".tab .badge")).toHaveCount(0);
});

test("settings: theme, daily goal, reset", async ({ page }) => {
  await page.goto("./#/me");
  await page.getByLabel("Theme").selectOption("dark");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.getByLabel("Daily goal").selectOption("3");
  await expect(page.getByText("Read 3 stories a day.")).toBeVisible();
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  page.once("dialog", (d) => d.accept());
  await page.getByRole("button", { name: "Reset all progress" }).click();
  await expect(page.getByText("Read 1 story a day.")).toBeVisible();
});
