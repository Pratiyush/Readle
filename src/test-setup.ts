// Node 25+ ships its own `localStorage` global, which is unusable without --localstorage-file and
// shadows jsdom's. Put jsdom's Storage back so store tests behave the same on every Node version.
const g = globalThis as unknown as { localStorage?: Storage; jsdom?: { window: Window } };
if (typeof g.localStorage?.getItem !== "function" && g.jsdom) {
  Object.defineProperty(globalThis, "localStorage", { value: g.jsdom.window.localStorage, configurable: true });
}
