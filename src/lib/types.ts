export type Level = "A1" | "A2" | "B1" | "B2";
export const LEVELS: Level[] = ["A1", "A2", "B1", "B2"];

export interface StoryMeta {
  id: string;
  title: string;
  level: Level;
  collection: string;
  publishedAt: string;
  image: string | null;
  /** 320 px copy of `image` for list cards (absent in older content). */
  thumb?: string | null;
  teaser: string;
  teaserEn: string;
  words: number;
  minutes: number;
}

/** A plain-text run, or [surface] / [surface, dictKey] / [surface, dictKey, 1 = compound head]. */
export type Token = string | [string] | [string, string] | [string, string, 1];

export interface Sentence {
  de: string;
  en: string;
  t: Token[];
}

export interface Story extends StoryMeta {
  sentences: Sentence[];
}

export interface DictEntry {
  h: string; // headword
  p: string; // part of speech
  en: string[];
  g?: "der" | "die" | "das";
  pl?: string;
  ipa?: string;
  cefr?: string;
  xd?: string; // example, German
  xe?: string; // example, English
  au?: string; // recorded pronunciation, relative to the content root
}

export type Dictionary = Record<string, DictEntry>;
