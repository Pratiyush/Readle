import { expect, type Page } from "@playwright/test";

/** Replace the device TTS with a recorder: each utterance "ends" after 150 ms. */
export async function stubSpeech(page: Page) {
  await page.addInitScript(() => {
    const w = window as unknown as { __spoken: string[] };
    w.__spoken = [];
    let current: SpeechSynthesisUtterance | null = null;
    const synth = window.speechSynthesis;
    synth.speak = (u: SpeechSynthesisUtterance) => {
      w.__spoken.push(u.text);
      current = u;
      setTimeout(() => {
        if (current === u) {
          current = null;
          u.onend?.(new Event("end") as SpeechSynthesisEvent);
        }
      }, 150);
    };
    synth.cancel = () => {
      const u = current;
      current = null;
      u?.onerror?.(new Event("error") as SpeechSynthesisErrorEvent);
    };
  });
}

export const spoken = (page: Page) => page.evaluate(() => (window as unknown as { __spoken: string[] }).__spoken.length);

export async function openStory(page: Page, id: string) {
  await page.goto(`./#/story/${id}`);
  await expect(page.locator(".reader h1")).toBeVisible();
}

export const word = (page: Page, text: string) => page.locator("button.w", { hasText: new RegExp(`^${text}$`) }).first();

/** Record what audio elements are asked to play instead of playing it. */
export async function stubAudio(page: Page) {
  await page.addInitScript(() => {
    const w = window as unknown as { __played: string[] };
    w.__played = [];
    HTMLMediaElement.prototype.play = function () {
      w.__played.push(this.src);
      return Promise.resolve();
    };
  });
}

export const played = (page: Page) => page.evaluate(() => (window as unknown as { __played: string[] }).__played);
