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
