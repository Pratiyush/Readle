import { href, parse, type Route } from "./router";

describe("router", () => {
  it("round-trips every route", () => {
    const routes: Route[] = [
      { name: "library" },
      { name: "story", id: "altes-haus" },
      { name: "quiz", id: "altes-haus" },
      { name: "words" },
      { name: "practice" },
      { name: "me" },
    ];
    for (const r of routes) expect(parse(href(r))).toEqual(r);
  });
  it("falls back to the library", () => {
    expect(parse("#/nonsense")).toEqual({ name: "library" });
    expect(parse("")).toEqual({ name: "library" });
  });
});
