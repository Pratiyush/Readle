import { useEffect, useMemo, useState } from "react";
import { imageUrl, loadLibrary } from "../lib/content";
import { useAsync } from "../hooks";
import { actions, continueStory, streak, useStore } from "../lib/store";
import { dayKey } from "../lib/dates";
import { rng } from "../lib/quiz";
import { LEVELS, type StoryMeta } from "../lib/types";
import { href, savedScroll } from "../router";

const COLLECTIONS: Record<string, string> = { all: "All", fiction: "Fiction", culture: "Culture", facts: "Facts" };

// Kept while the app runs, so coming back from a story lands on the same filters and list position.
const view = { collection: "all", query: "", unreadOnly: false };

export function Library() {
  const lib = useAsync(loadLibrary, []);
  const level = useStore((s) => s.settings.level);
  const read = useStore((s) => s.read);
  const days = useStore((s) => s.activeDays);
  const resumeId = useStore(continueStory);
  const [collection, setCollection] = useState(view.collection);
  const [query, setQuery] = useState(view.query);
  const [unreadOnly, setUnreadOnly] = useState(view.unreadOnly);
  Object.assign(view, { collection, query, unreadOnly });

  // The router scrolls to the top on every route change; put the list back where it was.
  useEffect(() => {
    if (lib.status === "ready") window.scrollTo(0, savedScroll({ name: "library" }));
  }, [lib.status]);

  const stories = lib.status === "ready" ? lib.value : [];
  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return stories.filter(
      (s) =>
        (level === "all" || s.level === level) &&
        (collection === "all" || s.collection === collection) &&
        (!unreadOnly || !read[s.id]) &&
        (!q || [s.title, s.teaser, s.teaserEn].some((t) => t.toLowerCase().includes(q))),
    );
  }, [stories, level, collection, unreadOnly, query, read]);

  const today = dayKey();
  const daily = useMemo(() => storyOfTheDay(stories, level, read, today), [stories, level, read, today]);
  const finishedToday = Object.values(read).filter((d) => d === today).length;
  const resume = resumeId ? stories.find((s) => s.id === resumeId) : undefined;

  return (
    <div className="page">
      <header className="lib-head">
        <div>
          <p className="eyebrow">Guten Tag!</p>
          <h1>Stories</h1>
        </div>
        <a className="streak-pill" href={href({ name: "me" })} title="Day streak">
          🔥 {streak(days)}
        </a>
      </header>

      {resume && (
        <a className="continue" href={href({ name: "story", id: resume.id })} data-testid="continue-card">
          {resume.image ? <img src={imageUrl(resume.thumb ?? resume.image)} alt="" /> : <span className="ph" />}
          <div className="continue-body">
            <span className="eyebrow">Continue reading</span>
            <h2 lang="de">{resume.title}</h2>
          </div>
          <span className="play" aria-hidden>
            ▶
          </span>
        </a>
      )}

      {daily && (
        <a className="daily" href={href({ name: "story", id: daily.id })}>
          {daily.image && <img src={imageUrl(daily.image)} alt="" />}
          <div className="daily-body">
            <span className="eyebrow light">{finishedToday ? "Keep going — next up" : "Story of the day"}</span>
            <h2 lang="de">{daily.title}</h2>
            <p>
              <span className={`lvl lvl-${daily.level}`}>{daily.level}</span> {daily.minutes} min · {COLLECTIONS[daily.collection] ?? daily.collection}
            </p>
          </div>
        </a>
      )}

      <div className="chips" role="group" aria-label="Level">
        <button className={level === "all" ? "chip on" : "chip"} aria-pressed={level === "all"} onClick={() => actions.updateSettings({ level: "all" })}>
          All levels
        </button>
        {LEVELS.map((l) => (
          <button key={l} className={level === l ? "chip on" : "chip"} aria-pressed={level === l} onClick={() => actions.updateSettings({ level: l })}>
            {l}
          </button>
        ))}
      </div>
      <div className="chips" role="group" aria-label="Collection">
        {Object.entries(COLLECTIONS).map(([k, label]) => (
          <button key={k} className={collection === k ? "chip on" : "chip"} aria-pressed={collection === k} onClick={() => setCollection(k)}>
            {label}
          </button>
        ))}
        <button className={unreadOnly ? "chip on" : "chip"} aria-pressed={unreadOnly} onClick={() => setUnreadOnly(!unreadOnly)}>
          Unread
        </button>
      </div>
      <input className="search" type="search" placeholder="Search stories…" value={query} onChange={(e) => setQuery(e.target.value)} />

      {lib.status === "loading" && <p className="muted center">Loading stories…</p>}
      {lib.status === "error" && <p className="muted center">Couldn't load stories. {lib.error}</p>}
      {lib.status === "ready" && !visible.length && <p className="muted center">No stories match these filters.</p>}

      <ul className="story-list">
        {visible.map((s) => (
          <li key={s.id}>
            <a className="story-card" href={href({ name: "story", id: s.id })}>
              <div className="thumb">{s.image ? <img src={imageUrl(s.thumb ?? s.image)} alt="" loading="lazy" /> : <span>📖</span>}</div>
              <div className="story-body">
                <h3 lang="de">{s.title}</h3>
                <p className="teaser">{s.teaserEn}</p>
                <p className="meta">
                  <span className={`lvl lvl-${s.level}`}>{s.level}</span>
                  {s.minutes} min · {COLLECTIONS[s.collection] ?? s.collection}
                  {read[s.id] && <span className="done">✓ Read</span>}
                </p>
              </div>
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

/**
 * Same pick all day, preferring unread stories. "All levels" goes in sequence, A1 → B2: the pick
 * comes from the lowest level that still has unread stories, so a beginner isn't handed B2 on day one.
 */
export function storyOfTheDay(stories: StoryMeta[], level: string, read: Record<string, string>, today: string) {
  const pool = stories.filter((s) => level === "all" || s.level === level);
  if (!pool.length) return null;
  let unread = pool.filter((s) => !read[s.id]);
  if (level === "all") {
    const next = LEVELS.find((l) => unread.some((s) => s.level === l));
    if (next) unread = unread.filter((s) => s.level === next);
  }
  const from = unread.length ? unread : pool;
  return from[Math.floor(rng(today)() * from.length)];
}
