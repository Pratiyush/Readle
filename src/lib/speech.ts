import { useEffect, useState } from "react";

/** German text-to-speech through the browser's own voices — no audio files to ship. */

let voice: SpeechSynthesisVoice | null | undefined;

export const speechAvailable = () => typeof window !== "undefined" && "speechSynthesis" in window;

function germanVoice(): SpeechSynthesisVoice | null {
  if (voice !== undefined) return voice;
  const voices = speechAvailable() ? window.speechSynthesis.getVoices() : [];
  if (!voices.length) return null; // not loaded yet; try again next call
  voice =
    voices.find((v) => v.lang === "de-DE" && /google|natural|premium|enhanced/i.test(v.name)) ??
    voices.find((v) => v.lang === "de-DE") ??
    voices.find((v) => v.lang.toLowerCase().replace("_", "-").startsWith("de")) ??
    null;
  return voice;
}

/**
 * Whether the device can read German aloud. Many browsers (Android WebView, some Linux builds)
 * have no German voice and would read the story with an English one, so Listen is offered only
 * once a German voice is known to exist. Voices load late in some browsers: listen for them.
 */
export function useGermanVoice(): boolean {
  const [has, setHas] = useState(() => germanVoice() !== null);
  useEffect(() => {
    if (!speechAvailable()) return;
    const on = () => {
      voice = undefined;
      setHas(germanVoice() !== null);
    };
    on();
    window.speechSynthesis.addEventListener?.("voiceschanged", on);
    return () => window.speechSynthesis.removeEventListener?.("voiceschanged", on);
  }, []);
  return has;
}

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
