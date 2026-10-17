/** German text-to-speech through the browser's own voices — no audio files to ship. */

let voice: SpeechSynthesisVoice | null | undefined;

function germanVoice(): SpeechSynthesisVoice | null {
  if (voice !== undefined) return voice;
  const voices = window.speechSynthesis?.getVoices() ?? [];
  if (!voices.length) return null; // not loaded yet; try again next call
  voice =
    voices.find((v) => v.lang === "de-DE" && /google|natural|premium|enhanced/i.test(v.name)) ??
    voices.find((v) => v.lang === "de-DE") ??
    voices.find((v) => v.lang.startsWith("de")) ??
    null;
  return voice;
}

export const speechAvailable = () => typeof window !== "undefined" && "speechSynthesis" in window;

export function speak(text: string, rate = 0.9, onEnd?: () => void): void {
  if (!speechAvailable()) {
    onEnd?.();
    return;
  }
  const u = new SpeechSynthesisUtterance(text);
  u.lang = "de-DE";
  u.rate = rate;
  const v = germanVoice();
  if (v) u.voice = v;
  if (onEnd) {
    u.onend = () => onEnd();
    u.onerror = () => onEnd();
  }
  window.speechSynthesis.speak(u);
}

export function stopSpeaking(): void {
  if (speechAvailable()) window.speechSynthesis.cancel();
}
