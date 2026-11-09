import type { Dictionary, Story } from "./types";

export interface Question {
  kind: "word" | "sentence";
  prompt: string;
  promptSub?: string;
  options: string[];
  answer: number;
}

/** Deterministic PRNG so a story's quiz is stable between visits and testable. */
export function rng(seed: string): () => number {
  let h = 2166136261;
  for (const c of seed) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return () => {
    h = Math.imul(h ^ (h >>> 15), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    return ((h ^= h >>> 16) >>> 0) / 4294967296;
  };
}

export function shuffle<T>(xs: T[], rand: () => number): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const CONTENT_POS = new Set(["noun", "verb", "adjective", "adverb"]);
const gloss = (e: Dictionary[string]) => e.en[0];

function withDistractors(correct: string, pool: string[], rand: () => number) {
  const others = shuffle([...new Set(pool.filter((p) => p !== correct))], rand).slice(0, 3);
  const options = shuffle([correct, ...others], rand);
  return { options, answer: options.indexOf(correct) };
}

/**
 * Up to three vocabulary questions (meaning of a content word from the story)
 * and two comprehension questions (which translation matches a sentence).
 */
export function buildQuiz(story: Story, dict: Dictionary, seed = story.id): Question[] {
  const rand = rng(seed);
  const questions: Question[] = [];

  const seen = new Map<string, { word: string; sentence: string }>();
  for (const s of story.sentences)
    for (const t of s.t)
      if (Array.isArray(t) && t.length === 2 && !seen.has(t[1])) {
        const e = dict[t[1]];
        if (e && CONTENT_POS.has(e.p) && e.h.length > 3) seen.set(t[1], { word: t[0], sentence: s.de });
      }
  const keys = [...seen.keys()];
  // Rarer words first: a quiz on "und" or "sein" teaches nothing.
  const ranked = shuffle(keys, rand).sort((a, b) => cefrRank(dict[b].cefr) - cefrRank(dict[a].cefr));
  const pool = Object.values(dict).filter((e) => CONTENT_POS.has(e.p));
  for (const key of ranked.slice(0, 3)) {
    const e = dict[key];
    // Distractors share the answer's part of speech: "to eat" next to "das Brot" gives it away.
    const same = (x: Dictionary[string]) => x.p === e.p;
    const candidates = [...keys.map((k) => dict[k]).filter(same), ...pool.filter(same).slice(0, 200)].map(gloss);
    const { options, answer } = withDistractors(gloss(e), candidates, rand);
    if (options.length < 2) continue;
    questions.push({
      kind: "word",
      prompt: e.g ? `${e.g} ${e.h}` : e.h,
      promptSub: seen.get(key)!.sentence,
      options,
      answer,
    });
  }

  if (story.sentences.length >= 4) {
    const picks = shuffle(story.sentences.map((_, i) => i), rand).slice(0, 2);
    for (const i of picks) {
      const s = story.sentences[i];
      const { options, answer } = withDistractors(s.en, story.sentences.map((x) => x.en), rand);
      questions.push({ kind: "sentence", prompt: s.de, options, answer });
    }
  }
  return questions;
}

function cefrRank(c?: string): number {
  return c ? ["A1", "A2", "B1", "B2", "C1"].indexOf(c) : -1;
}

/** Praise that matches the score: "Gut gemacht! 🎉" at 20% read as a joke. Same tiers as the app. */
export function praise(pct: number): [emoji: string, headline: string] {
  if (pct >= 80) return ["🎉", "Gut gemacht!"];
  if (pct >= 50) return ["👍", "Nicht schlecht!"];
  return ["📖", "Weiter so!"];
}
