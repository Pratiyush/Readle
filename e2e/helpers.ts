import { expect, type Page } from "@playwright/test";

/**
 * Replace the device TTS with a recorder: each utterance "ends" after 150 ms. The device has a
 * German voice unless `german` is false (then it only has an English one).
 */
export async function stubSpeech(page: Page, { german = true } = {}) {
  await page.addInitScript((german) => {
    const w = window as unknown as { __spoken: string[] };
    w.__spoken = [];
    let current: SpeechSynthesisUtterance | null = null;
    const synth = window.speechSynthesis;
    const voices = [{ lang: "en-US", name: "English", default: true, localService: true, voiceURI: "en" }];
    if (german) voices.push({ lang: "de-DE", name: "Deutsch", default: false, localService: true, voiceURI: "de" });
    synth.getVoices = () => voices as SpeechSynthesisVoice[];
    // The fakes aren't real SpeechSynthesisVoice objects, which the real setter rejects.
    Object.defineProperty(SpeechSynthesisUtterance.prototype, "voice", {
      configurable: true,
      get() {
        return (this as { _voice?: unknown })._voice ?? null;
      },
      set(v) {
        (this as { _voice?: unknown })._voice = v;
      },
    });
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
  }, german);
}

export const spokenTexts = (page: Page) => page.evaluate(() => (window as unknown as { __spoken: string[] }).__spoken);

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
