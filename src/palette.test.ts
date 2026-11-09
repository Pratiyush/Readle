// Owner rule: no Claude colours (coral, salmon, peach, pink, terracotta, and Claude's cream paper).
// Same bands as German/tools/colour-audit.mjs, plus cream. One deep flag-red is allowed (errors only).
import { readFileSync } from "node:fs";
import { join } from "node:path";

export function claudeish(hex: string): string | null {
  const n = parseInt(hex.length === 3 ? [...hex].map((c) => c + c).join("") : hex, 16);
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => v / 255);
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, d = mx - mn;
  if (!d) return null;
  const s = d / (1 - Math.abs(2 * l - 1));
  let h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  h *= 60;
  if (h < 0) h += 360;
  if ((h >= 345 || h <= 32) && s >= 0.35 && l >= 0.5 && l <= 0.93) return "coral/salmon/peach";
  if (h >= 5 && h <= 32 && s >= 0.35 && s <= 0.8 && l >= 0.38 && l < 0.5) return "terracotta";
  if (h >= 300 && h < 345 && s >= 0.3 && l >= 0.45 && l <= 0.93) return "pink";
  if (h >= 20 && h <= 42 && s >= 0.2 && l >= 0.85) return "cream";
  return null;
}

describe("no Claude colours (owner rule)", () => {
  it("the band check itself", () => {
    expect(claudeish("f87171")).toBe("coral/salmon/peach");
    expect(claudeish("fbf8f3")).toBe("cream");
    expect(claudeish("d97757")).toBe("coral/salmon/peach");
    expect(claudeish("b91c1c")).toBeNull(); // the allowed flag-red
    expect(claudeish("fef3c7")).toBeNull(); // amber
    expect(claudeish("f6f8f7")).toBeNull();
  });

  it.each(["src/styles.css", "public/icon.svg", "public/manifest.webmanifest", "index.html"])("%s", (file) => {
    const text = readFileSync(join(process.cwd(), file), "utf8");
    const hits = [...text.matchAll(/#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b/g)]
      .map((m) => [m[0], claudeish(m[1])])
      .filter(([, why]) => why);
    expect(hits).toEqual([]);
  });
});
