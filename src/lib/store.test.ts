import { actions, getState, streak } from "./store";

describe("streak", () => {
  it("counts consecutive days ending today", () => {
    expect(streak(["2026-10-15", "2026-10-16", "2026-10-17"], "2026-10-17")).toBe(3);
  });
  it("keeps yesterday's streak alive until today is over", () => {
    expect(streak(["2026-10-15", "2026-10-16"], "2026-10-17")).toBe(2);
  });
  it("resets after a missed day", () => {
    expect(streak(["2026-10-14", "2026-10-15"], "2026-10-17")).toBe(0);
  });
});

describe("actions", () => {
  beforeEach(() => actions.reset());

  it("finishing a story records the first day and marks it active", () => {
    actions.finishStory("brot", "2026-10-16");
    actions.finishStory("brot", "2026-10-17");
    expect(getState().read.brot).toBe("2026-10-16");
    expect(getState().activeDays).toEqual(["2026-10-16", "2026-10-17"]);
  });

  it("toggles saved words and persists them", () => {
    const w = { key: "de.haus.n", word: "Haus", storyId: "x", context: "Das Haus ist alt." };
    actions.toggleWord(w, "2026-10-17");
    expect(getState().words["de.haus.n"].card).toEqual({ box: 0, due: "2026-10-17" });
    expect(JSON.parse(localStorage.getItem("readle.state.v1")!).words["de.haus.n"]).toBeTruthy();
    actions.toggleWord(w);
    expect(getState().words["de.haus.n"]).toBeUndefined();
  });

  it("keeps the best quiz score", () => {
    actions.recordQuiz("x", 0.8);
    actions.recordQuiz("x", 0.4);
    expect(getState().quiz.x).toBe(0.8);
  });
});
