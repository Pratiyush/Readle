import type { Token } from "./types";

type Word = Exclude<Token, string>;
export type Unit = string | { pre: string; tok: Word; post: string };

/**
 * Word buttons are atomic inlines, so the browser may break a line on either side of one and
 * strand "." or "," at the start of the next line. Glue the punctuation that touches a word
 * (closing marks after it, opening quotes before it) into one unit rendered with nowrap.
 */
export function glue(tokens: Token[]): Unit[] {
  const out: Unit[] = [];
  let carry = "";
  tokens.forEach((t, j) => {
    if (typeof t !== "string") {
      out.push({ pre: carry, tok: t, post: "" });
      carry = "";
      return;
    }
    let rest = t;
    const prev = out[out.length - 1];
    if (prev && typeof prev !== "string" && j > 0 && typeof tokens[j - 1] !== "string") {
      const head = /^\S*/.exec(rest)![0];
      prev.post += head;
      rest = rest.slice(head.length);
    }
    if (j + 1 < tokens.length && typeof tokens[j + 1] !== "string") {
      carry = /\S*$/.exec(rest)![0];
      rest = rest.slice(0, rest.length - carry.length);
    }
    if (rest) out.push(rest);
  });
  return out;
}
