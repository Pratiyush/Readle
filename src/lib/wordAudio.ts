import { audioUrl } from "./content";
import { speak, stopSpeaking } from "./speech";
import type { DictEntry } from "./types";

let player: HTMLAudioElement | null = null;

/**
 * Say a word: Lernle's recorded clip when the entry has one, the device's German voice otherwise
 * (names, words without a clip, or a clip that fails to play). One player, so taps never overlap.
 */
export function playWord(entry: DictEntry | undefined, text: string, rate: number): void {
  player?.pause();
  stopSpeaking();
  const url = audioUrl(entry);
  if (!url) {
    speak(text, rate);
    return;
  }
  player ??= new Audio();
  player.src = url;
  player.play().catch(() => speak(text, rate));
}

export function stopWord(): void {
  player?.pause();
}
