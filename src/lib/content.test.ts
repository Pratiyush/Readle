// Integrity of the compiled content in public/content (run `npm run content` to rebuild).
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { buildQuiz } from "./quiz";
import type { Dictionary, Story, StoryMeta } from "./types";

const dir = join(process.cwd(), "public/content");
const read = <T>(p: string): T => JSON.parse(readFileSync(join(dir, p), "utf8"));
const library = read<StoryMeta[]>("stories.json");
const dict = read<Dictionary>("dict.json");
const stories = library.map((m) => read<Story>(`stories/${m.id}.json`));

describe("content", () => {
  it("has stories at every level", () => {
    expect(library.length).toBeGreaterThan(50);
    for (const l of ["A1", "A2", "B1", "B2"]) expect(library.some((s) => s.level === l)).toBe(true);
    expect(readdirSync(join(dir, "stories")).length).toBe(library.length);
  });

  it("every image the library names exists", () => {
    for (const s of library) if (s.image) expect(existsSync(join(dir, s.image)), s.image).toBe(true);
  });

  it("tokens reassemble each sentence exactly and link only to real entries", () => {
    for (const story of stories)
      for (const s of story.sentences) {
        expect(s.t.map((t) => (typeof t === "string" ? t : t[0])).join("")).toBe(s.de);
        for (const t of s.t) if (Array.isArray(t) && t[1]) expect(dict[t[1]], `${story.id}: ${t[1]}`).toBeTruthy();
      }
  });

  it("every recorded pronunciation the dictionary names exists, for most entries", () => {
    const withAudio = Object.values(dict).filter((e) => e.au);
    expect(withAudio.length / Object.keys(dict).length).toBeGreaterThan(0.85);
    for (const e of withAudio) {
      expect(e.au, e.h).toMatch(/^audio\/[A-Za-z0-9._-]+\.mp3$/);
      expect(existsSync(join(dir, e.au!)), e.au).toBe(true);
    }
  });

  it("links at least 95% of words to the dictionary", () => {
    let words = 0;
    let linked = 0;
    for (const story of stories)
      for (const s of story.sentences)
        for (const t of s.t)
          if (Array.isArray(t)) {
            words++;
            if (t[1]) linked++;
          }
    expect(linked / words).toBeGreaterThan(0.95);
  });

  it("word questions offer distractors of the same part of speech", () => {
    const posOf = new Map<string, Set<string>>();
    for (const e of Object.values(dict)) posOf.set(e.en[0], (posOf.get(e.en[0]) ?? new Set()).add(e.p));
    for (const story of stories)
      for (const q of buildQuiz(story, dict).filter((x) => x.kind === "word")) {
        const shared = q.options.map((o) => posOf.get(o)!).reduce((a, b) => new Set([...a].filter((p) => b.has(p))));
        expect(shared.size, `${story.id}: ${q.prompt} → ${q.options.join(" / ")}`).toBeGreaterThan(0);
      }
  });

  it("every story yields a solvable quiz", () => {
    for (const story of stories) {
      const qs = buildQuiz(story, dict);
      expect(qs.length, story.id).toBeGreaterThanOrEqual(3);
      for (const q of qs) {
        expect(q.options[q.answer]).toBeDefined();
        expect(new Set(q.options).size).toBe(q.options.length);
      }
    }
  });
});

describe("word clips (BUG-26)", () => {
  // Words Lernle has no recording of (in any part of speech). They fall back to the device voice
  // until Lernle's pipeline records them; anything else without a clip is a matching bug.
  const UNRECORDED = ["ab", "ander", "Band", "Bayern", "bekommen", "bisschen", "Brauerei", "dabei", "dafür", "dahin", "daran", "darauf", "darin", "darum", "davon", "dazu", "derselbe", "Deutsche", "Europa", "Fensterladen", "gar", "Gegend", "Gemütlichkeit", "heraus", "herein", "hin", "je", "klingen", "Köln", "Kübel", "Mal", "meist", "nennen", "Raum", "reden", "Rhein", "Schweiz", "selbst", "solch", "sorgen", "still", "Verkäuferin", "verlangen", "weg", "worauf", "zurück", "ändern",
    // BUG-42: nouns added to Readle's supplement so their words stop linking to look-alike verbs
    "Begriff", "Bügel", "Duft", "Hang", "Nähe", "Schiene", "Schluck", "Strich"];

  it("every word Lernle recorded has its clip; only the known unrecorded ones fall back", () => {
    const missing = [...new Set(Object.values(dict).filter((e) => !e.au).map((e) => e.h))].sort((a, b) => a.localeCompare(b, "de"));
    expect(missing).toEqual([...UNRECORDED].sort((a, b) => a.localeCompare(b, "de")));
  });

  it("every clip a dictionary entry names exists", () => {
    for (const e of Object.values(dict)) if (e.au) expect(existsSync(join(dir, e.au)), e.au).toBe(true);
  });
});
