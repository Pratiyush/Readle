import { useMemo, useState } from "react";
import { loadDictionary } from "../lib/content";
import { useAsync } from "../hooks";
import { actions, useStore } from "../lib/store";
import { isDue, isMastered } from "../lib/srs";
import { dayKey } from "../lib/dates";
import { playWord } from "../lib/wordAudio";
import { href } from "../router";

type Filter = "all" | "due" | "learning" | "mastered";

export function Words() {
  const dict = useAsync(loadDictionary, []);
  const words = useStore((s) => s.words);
  const rate = useStore((s) => s.settings.speechRate);
  const [filter, setFilter] = useState<Filter>("all");
  const today = dayKey();

  const list = useMemo(
    () =>
      Object.values(words)
        .filter((w) =>
          filter === "due" ? isDue(w.card, today) : filter === "mastered" ? isMastered(w.card) : filter === "learning" ? !isMastered(w.card) : true,
        )
        .sort((a, b) => b.added.localeCompare(a.added) || a.word.localeCompare(b.word, "de")),
    [words, filter, today],
  );
  const due = Object.values(words).filter((w) => isDue(w.card, today)).length;
  const total = Object.keys(words).length;
  const d = dict.status === "ready" ? dict.value : {};

  return (
    <div className="page">
      <header className="lib-head">
        <div>
          <p className="eyebrow">Your vocabulary</p>
          <h1>Words</h1>
        </div>
      </header>

      <div className="practice-card">
        <div>
          <b>{due ? `${due} word${due === 1 ? "" : "s"} to review` : total ? "All caught up!" : "No words yet"}</b>
          <p className="muted small">
            {total ? `${total} saved · spaced repetition brings each word back just before you'd forget it.` : "Tap words while reading and save them here."}
          </p>
        </div>
        {due > 0 && (
          <a className="btn" href={href({ name: "practice" })}>
            Practice
          </a>
        )}
      </div>

      {total > 0 && (
        <div className="chips" role="group" aria-label="Filter words">
          {(["all", "due", "learning", "mastered"] as Filter[]).map((f) => (
            <button key={f} className={filter === f ? "chip on" : "chip"} onClick={() => setFilter(f)}>
              {f[0].toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      )}

      <ul className="word-list">
        {list.map((w) => {
          const e = d[w.key];
          return (
            <li key={w.key} className="word-row">
              <button className="icon-btn" aria-label={`Pronounce ${w.word}`} onClick={() => playWord(e, e?.h ?? w.word, rate)}>
                🔊
              </button>
              <div className="word-main">
                <b lang="de">{e ? (e.g ? `${e.g} ${e.h}` : e.h) : w.word}</b>
                <span className="muted">{e ? e.en.slice(0, 2).join(", ") : "—"}</span>
              </div>
              <span className="boxes" title={`Strength ${w.card.box} of 6`}>
                {[1, 2, 3, 4, 5].map((n) => (
                  <i key={n} className={w.card.box >= n ? "on" : ""} />
                ))}
              </span>
              <button className="icon-btn" aria-label={`Remove ${w.word}`} onClick={() => actions.toggleWord(w)}>
                🗑
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
