// Edge and boundary cases (German/docs/e2e-standard.md, docs/test-plan.md). Dates run in
// Europe/Berlin whatever the machine's zone, so DST nights are real.
process.env.TZ = "Europe/Berlin";
import { addDays, dayKey, daysBetween } from "./dates";
import { praise } from "./quiz";

describe("time in Europe/Berlin", () => {
  it("DST nights are one calendar day, not 23 or 25 hours", () => {
    expect(addDays("2026-03-28", 1)).toBe("2026-03-29");
    expect(addDays("2026-03-29", 1)).toBe("2026-03-30");
    expect(addDays("2026-10-25", 1)).toBe("2026-10-26");
    expect(addDays("2026-10-26", -1)).toBe("2026-10-25");
    expect(daysBetween("2026-03-28", "2026-03-30")).toBe(2);
    expect(daysBetween("2026-10-24", "2026-10-26")).toBe(2);
  });
  it("leap day and year end", () => {
    expect(addDays("2028-02-28", 1)).toBe("2028-02-29");
    expect(addDays("2028-02-29", 1)).toBe("2028-03-01");
    expect(addDays("2027-02-28", 1)).toBe("2027-03-01");
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
  });
  it("midnight: 23:59:59 is today, 00:00 tomorrow", () => {
    expect(dayKey(new Date(2026, 10, 9, 23, 59, 59))).toBe("2026-11-09");
    expect(dayKey(new Date(2026, 10, 10, 0, 0, 0))).toBe("2026-11-10");
  });
});

describe("numbers at the edges", () => {
  it("quiz praise at 0, 49, 50, 79, 80 and 100 %", () => {
    expect([0, 49, 50, 79, 80, 100].map((p) => praise(p)[1])).toEqual([
      "Weiter so!", "Weiter so!", "Nicht schlecht!", "Nicht schlecht!", "Gut gemacht!", "Gut gemacht!",
    ]);
  });
});

describe("saved state from storage", () => {
  const boot = async (raw: string) => {
    localStorage.setItem("readle.state.v1", raw);
    vi.resetModules();
    return (await import("./store")).getState();
  };
  afterEach(() => localStorage.clear());

  it("corrupt or truncated JSON starts fresh", async () => {
    for (const raw of ["{not json", '{"read": {"brot": "2026-11-0', "[]", "null", '"text"']) {
      const s = await boot(raw);
      expect(s.read, raw).toEqual({});
      expect(s.settings.level, raw).toBe("all");
    }
  });

  it("a bad entry is dropped alone: one broken word can't take the app down", async () => {
    const s = await boot(
      JSON.stringify({
        read: { brot: "2026-11-08", bad: 7 },
        progress: { brot: "three", kaffee: 4 },
        words: {
          "de.geben.v": { key: "de.geben.v", word: "geben", storyId: "brot", context: "x", added: "2026-11-08", card: { box: 1, due: "2026-11-09" } },
          broken: "not a word",
          nocard: { key: "nocard", word: "x" },
        },
        activeDays: ["2026-11-08", 7],
        settings: { level: "B1", fontScale: "big" },
      }),
    );
    expect(s.read).toEqual({ brot: "2026-11-08" });
    expect(s.progress).toEqual({ kaffee: 4 });
    expect(Object.keys(s.words)).toEqual(["de.geben.v"]);
    expect(s.activeDays).toEqual(["2026-11-08"]);
    expect(s.settings.level).toBe("B1");
    expect(s.settings.fontScale).toBe(1);
  });
});
