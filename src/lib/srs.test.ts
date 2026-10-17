import { isDue, isMastered, newCard, review, INTERVALS } from "./srs";
import { addDays, daysBetween } from "./dates";

describe("srs", () => {
  const today = "2026-10-17";

  it("new cards are due immediately", () => {
    expect(isDue(newCard(today), today)).toBe(true);
  });

  it("climbs a box and schedules by its interval on a correct answer", () => {
    const c = review(newCard(today), true, today);
    expect(c.box).toBe(1);
    expect(c.due).toBe(addDays(today, INTERVALS[1]));
    expect(isDue(c, today)).toBe(false);
  });

  it("drops to box 0 and stays due on a miss", () => {
    let c = newCard(today);
    for (let i = 0; i < 4; i++) c = review(c, true, today);
    c = review(c, false, today);
    expect(c).toEqual({ box: 0, due: today });
  });

  it("caps at the last box and marks mastery", () => {
    let c = newCard(today);
    for (let i = 0; i < 20; i++) c = review(c, true, today);
    expect(c.box).toBe(INTERVALS.length - 1);
    expect(isMastered(c)).toBe(true);
  });
});

describe("dates", () => {
  it("adds days across month and year ends", () => {
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
    expect(addDays("2026-03-01", -1)).toBe("2026-02-28");
    expect(daysBetween("2026-10-01", "2026-10-17")).toBe(16);
  });
});
