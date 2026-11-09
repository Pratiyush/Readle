import { useSyncExternalStore } from "react";
import { addDays, dayKey } from "./dates";
import { newCard, review, type Card } from "./srs";
import type { Level } from "./types";

export interface SavedWord {
  key: string; // dictionary key, or "free:<word>" for words without an entry
  word: string; // headword (or the word itself without an entry)
  surface?: string; // the form met in the story ("gibt" for geben), to blank it in practice
  storyId: string;
  context: string; // the sentence it came from
  added: string;
  card: Card;
}

export interface Settings {
  level: Level | "all";
  fontScale: number;
  theme: "system" | "light" | "dark";
  dailyGoal: number; // stories per day
  speechRate: number;
  autoPlayWords: boolean; // say a word when it is tapped
}

export interface State {
  version: 1;
  read: Record<string, string>; // storyId → day finished
  progress: Record<string, number>; // storyId → furthest sentence index reached
  quiz: Record<string, number>; // storyId → best score 0..1
  words: Record<string, SavedWord>;
  activeDays: string[]; // sorted, unique
  lastStory: string | null; // opened most recently, for "Continue reading"
  wordTipSeen: boolean; // the first-run "tap any word" cue has done its job
  settings: Settings;
}

const KEY = "readle.state.v1";

export const defaultState = (): State => ({
  version: 1,
  read: {},
  progress: {},
  quiz: {},
  words: {},
  activeDays: [],
  lastStory: null,
  wordTipSeen: false,
  settings: { level: "all", fontScale: 1, theme: "system", dailyGoal: 1, speechRate: 0.9, autoPlayWords: true },
});

function parse(raw: string | null): State | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as State;
    const d = defaultState();
    return { ...d, ...parsed, settings: { ...d.settings, ...parsed.settings } };
  } catch {
    return null; // corrupt data
  }
}

function loadState(): State {
  try {
    return parse(localStorage.getItem(KEY)) ?? defaultState();
  } catch {
    return defaultState(); // private mode: start fresh
  }
}

let state = loadState();
const listeners = new Set<() => void>();

// Another tab of the app saved: take its state, so this tab's next save builds on it instead of
// overwriting it (two open tabs used to lose each other's words and progress).
if (typeof window !== "undefined") {
  window.addEventListener("storage", (e) => {
    if (e.key !== KEY) return;
    state = parse(e.newValue) ?? defaultState();
    listeners.forEach((l) => l());
  });
}

function commit(next: State) {
  state = next;
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* storage full or unavailable: keep the in-memory state */
  }
  listeners.forEach((l) => l());
}

export const getState = () => state;

export function useStore<T>(select: (s: State) => T): T {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => select(state),
  );
}

function markActive(s: State, today: string): string[] {
  return s.activeDays.includes(today) ? s.activeDays : [...s.activeDays, today].sort();
}

export const actions = {
  finishStory(storyId: string, today = dayKey()) {
    commit({
      ...state,
      read: { ...state.read, [storyId]: state.read[storyId] ?? today },
      activeDays: markActive(state, today),
    });
  },
  openStory(storyId: string) {
    if (state.lastStory === storyId) return;
    commit({ ...state, lastStory: storyId });
  },
  markWordTipSeen() {
    if (!state.wordTipSeen) commit({ ...state, wordTipSeen: true });
  },
  setProgress(storyId: string, index: number) {
    if ((state.progress[storyId] ?? -1) >= index) return;
    commit({ ...state, progress: { ...state.progress, [storyId]: index } });
  },
  recordQuiz(storyId: string, score: number) {
    commit({ ...state, quiz: { ...state.quiz, [storyId]: Math.max(score, state.quiz[storyId] ?? 0) } });
  },
  toggleWord(w: Omit<SavedWord, "added" | "card">, today = dayKey()) {
    const words = { ...state.words };
    if (words[w.key]) delete words[w.key];
    else words[w.key] = { ...w, added: today, card: newCard(today) };
    commit({ ...state, words });
  },
  reviewWord(key: string, correct: boolean, today = dayKey()) {
    const w = state.words[key];
    if (!w) return;
    commit({
      ...state,
      words: { ...state.words, [key]: { ...w, card: review(w.card, correct, today) } },
      activeDays: markActive(state, today),
    });
  },
  updateSettings(patch: Partial<Settings>) {
    commit({ ...state, settings: { ...state.settings, ...patch } });
  },
  reset() {
    commit(defaultState());
  },
};

/** The story to offer as "Continue reading": opened last, started, not finished. */
export function continueStory(s: State): string | null {
  const id = s.lastStory;
  return id && !s.read[id] && (s.progress[id] ?? 0) > 0 ? id : null;
}

/** Consecutive active days ending today, or yesterday if today isn't done yet. */
export function streak(activeDays: string[], today = dayKey()): number {
  const days = new Set(activeDays);
  let cursor = days.has(today) ? today : addDays(today, -1);
  let n = 0;
  while (days.has(cursor)) {
    n++;
    cursor = addDays(cursor, -1);
  }
  return n;
}
