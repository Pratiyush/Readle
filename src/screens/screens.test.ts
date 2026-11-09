// Pure helpers behind the screens: blanking in practice, the story of the day, quiz praise, CSS.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { blank } from "./Practice";
import { storyOfTheDay } from "./Library";
import { praise } from "../lib/quiz";
import type { StoryMeta } from "../lib/types";

describe("practice blanks the word in its sentence (BUG-17)", () => {
  it("blanks the form met in the story, not only the headword", () => {
    expect(blank("Er gibt mir das Brot.", ["gibt", "geben"])).toBe("Er ＿＿＿ mir das Brot.");
  });
  it("handles umlauts and ß at word edges", () => {
    expect(blank("Die Äpfel sind rot.", ["Äpfel", "Apfel"])).toBe("Die ＿＿＿ sind rot.");
    expect(blank("Mein Fuß tut weh.", [undefined, "Fuß"])).toBe("Mein ＿＿＿ tut weh.");
  });
  it("never blanks part of a longer word", () => {
    expect(blank("Das Brotmesser ist scharf.", [undefined, "Brot"])).toBe("Das Brotmesser ist scharf.");
  });
  it("falls back to the headword for words saved before surfaces were kept", () => {
    expect(blank("Ich kaufe Brot.", [undefined, "Brot"])).toBe("Ich kaufe ＿＿＿.");
  });
});

describe("quiz praise matches the score (BUG-18)", () => {
  it.each([
    [100, "Gut gemacht!"],
    [80, "Gut gemacht!"],
    [60, "Nicht schlecht!"],
    [20, "Weiter so!"],
    [0, "Weiter so!"],
  ])("%i%% → %s", (pct, headline) => expect(praise(pct)[1]).toBe(headline));
});

describe("story of the day", () => {
  const story = (id: string, level: string) => ({ id, level }) as StoryMeta;
  const lib = [story("b2", "B2"), story("a2a", "A2"), story("a1a", "A1"), story("a1b", "A1"), story("b1", "B1")];

  it("all levels go in sequence: A1 first, then A2 once A1 is read", () => {
    for (const day of ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"])
      expect(storyOfTheDay(lib, "all", {}, day)!.level).toBe("A1");
    expect(storyOfTheDay(lib, "all", { a1a: "d", a1b: "d" }, "2026-11-09")!.id).toBe("a2a");
    expect(storyOfTheDay(lib, "all", { a1a: "d", a1b: "d", a2a: "d" }, "2026-11-09")!.id).toBe("b1");
  });
  it("a chosen level stays within it", () => {
    expect(storyOfTheDay(lib, "B2", {}, "2026-11-09")!.id).toBe("b2");
  });
  it("offers a read story again once everything is read", () => {
    const all = Object.fromEntries(lib.map((s) => [s.id, "d"]));
    expect(storyOfTheDay(lib, "all", all, "2026-11-09")).toBeTruthy();
  });
});

describe("edge-to-edge layout (BUG-13)", () => {
  const css = readFileSync(join(process.cwd(), "src/styles.css"), "utf8");
  const rule = (selector: string) => css.match(new RegExp(`(^|\\n)${selector.replace(".", "\\.")} \\{([^}]*)\\}`))?.[2] ?? "";
  it("page and reader headers clear the status bar / notch", () => {
    expect(rule(".page")).toContain("env(safe-area-inset-top)");
    expect(rule(".reader-bar")).toContain("env(safe-area-inset-top)");
    expect(readFileSync(join(process.cwd(), "index.html"), "utf8")).toContain("viewport-fit=cover");
  });
});
