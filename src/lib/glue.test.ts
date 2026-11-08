import { glue } from "./glue";
import type { Token } from "./types";

const words = (units: ReturnType<typeof glue>) =>
  units.map((u) => (typeof u === "string" ? u : `${u.pre}[${u.tok[0]}]${u.post}`)).join("|");

describe("glue", () => {
  it("keeps closing punctuation with the word before it", () => {
    const t: Token[] = [["Es", "k"], " ", ["gibt", "k"], ": ", ["hell", "k"], ", ", ["dunkel", "k"], "."];
    expect(words(glue(t))).toBe("[Es]| |[gibt]:| |[hell],| |[dunkel].");
  });

  it("keeps opening quotes with the word after it", () => {
    const t: Token[] = ["„", ["Hallo"], "!“ ", ["sagt", "k"], " — ", ["sie", "k"], "."];
    expect(words(glue(t))).toBe("„[Hallo]!“| |[sagt]| — |[sie].");
  });

  it("loses no text", () => {
    const t: Token[] = [["Brot", "k"], " ist ", ["Kultur", "k"], " (", ["sagt", "k"], ")."];
    const text = glue(t)
      .map((u) => (typeof u === "string" ? u : u.pre + u.tok[0] + u.post))
      .join("");
    expect(text).toBe("Brot ist Kultur (sagt).");
  });
});
