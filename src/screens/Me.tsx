import { loadLibrary } from "../lib/content";
import { useAsync } from "../hooks";
import { actions, streak, useStore } from "../lib/store";
import { isMastered } from "../lib/srs";
import { addDays, dayKey } from "../lib/dates";
import { LEVELS } from "../lib/types";

export function Me() {
  const lib = useAsync(loadLibrary, []);
  const s = useStore((x) => x);
  const today = dayKey();
  const readToday = Object.values(s.read).filter((d) => d === today).length;
  const goal = s.settings.dailyGoal;
  const words = Object.values(s.words);
  const byLevel = LEVELS.map((l) => {
    const all = lib.status === "ready" ? lib.value.filter((x) => x.level === l) : [];
    return { level: l, total: all.length, read: all.filter((x) => s.read[x.id]).length };
  });
  const week = Array.from({ length: 7 }, (_, i) => addDays(today, i - 6));
  const active = new Set(s.activeDays);

  return (
    <div className="page">
      <header className="lib-head">
        <div>
          <p className="eyebrow">Your progress</p>
          <h1>Progress</h1>
        </div>
      </header>

      <section className="panel">
        <div className="goal">
          <div className="ring" style={{ ["--p" as string]: Math.min(1, readToday / goal) }}>
            <span>
              {Math.min(readToday, goal)}/{goal}
            </span>
          </div>
          <div>
            <b>{readToday >= goal ? "Daily goal reached! 🎉" : "Today's goal"}</b>
            <p className="muted small">
              Read {goal} {goal === 1 ? "story" : "stories"} a day.
            </p>
          </div>
        </div>
        <div className="week">
          {week.map((d) => (
            <div key={d} className={active.has(d) ? "day on" : "day"}>
              <i>{active.has(d) ? "🔥" : ""}</i>
              <span>{new Date(d + "T12:00").toLocaleDateString(undefined, { weekday: "narrow" })}</span>
            </div>
          ))}
        </div>
      </section>

      <div className="stat-grid">
        <div className="stat">
          <b>🔥 {streak(s.activeDays)}</b>
          <span>day streak</span>
        </div>
        <div className="stat">
          <b>{Object.keys(s.read).length}</b>
          <span>stories read</span>
        </div>
        <div className="stat">
          <b>{words.length}</b>
          <span>words saved</span>
        </div>
        <div className="stat">
          <b>{words.filter((w) => isMastered(w.card)).length}</b>
          <span>words mastered</span>
        </div>
      </div>

      <section className="panel">
        <h2>Stories by level</h2>
        {byLevel.map((b) => (
          <div key={b.level} className="level-row">
            <span className={`lvl lvl-${b.level}`}>{b.level}</span>
            <div className="bar">
              <i style={{ width: b.total ? `${(100 * b.read) / b.total}%` : 0 }} />
            </div>
            <span className="muted small">
              {b.read}/{b.total}
            </span>
          </div>
        ))}
      </section>

      <section className="panel settings">
        <h2>Settings</h2>
        <label>
          Daily goal
          <select value={goal} onChange={(e) => actions.updateSettings({ dailyGoal: Number(e.target.value) })}>
            {[1, 2, 3, 5].map((n) => (
              <option key={n} value={n}>
                {n} {n === 1 ? "story" : "stories"}
              </option>
            ))}
          </select>
        </label>
        <label>
          Theme
          <select value={s.settings.theme} onChange={(e) => actions.updateSettings({ theme: e.target.value as "system" | "light" | "dark" })}>
            <option value="system">System</option>
            <option value="light">Light</option>
            <option value="dark">Dark</option>
          </select>
        </label>
        <label>
          Speech speed
          <select value={s.settings.speechRate} onChange={(e) => actions.updateSettings({ speechRate: Number(e.target.value) })}>
            <option value={0.7}>Slow</option>
            <option value={0.9}>Normal</option>
            <option value={1.05}>Fast</option>
          </select>
        </label>
        <label className="toggle">
          Say words when tapped
          <input
            type="checkbox"
            checked={s.settings.autoPlayWords}
            onChange={(e) => actions.updateSettings({ autoPlayWords: e.target.checked })}
          />
        </label>
        <button
          className="btn secondary danger"
          onClick={() => {
            if (confirm("Delete all progress and saved words? This can't be undone.")) actions.reset();
          }}
        >
          Reset all progress
        </button>
      </section>

      <p className="muted small center credits">
        Stories and dictionary from the Lernle project. German text is machine-assisted and awaiting native review.
      </p>
    </div>
  );
}
