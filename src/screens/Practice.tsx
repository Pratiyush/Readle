import { useMemo, useState } from "react";
import { loadDictionary } from "../lib/content";
import { useAsync } from "../hooks";
import { actions, getState, useStore } from "../lib/store";
import { isDue } from "../lib/srs";
import { dayKey } from "../lib/dates";
import { playWord } from "../lib/wordAudio";
import { href } from "../router";

const SESSION_SIZE = 20;

export function Practice() {
  const dict = useAsync(loadDictionary, []);
  const rate = useStore((s) => s.settings.speechRate);
  // Snapshot the queue once: reviewing a card must not reshuffle the session.
  const [queue] = useState(() =>
    Object.values(getState().words)
      .filter((w) => isDue(w.card, dayKey()))
      .sort((a, b) => a.card.box - b.card.box || a.card.due.localeCompare(b.card.due))
      .slice(0, SESSION_SIZE)
      .map((w) => w.key),
  );
  const [index, setIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [right, setRight] = useState(0);
  const words = useStore((s) => s.words);
  const d = dict.status === "ready" ? dict.value : {};

  const current = useMemo(() => words[queue[index]], [words, queue, index]);

  if (index >= queue.length || !current) {
    return (
      <div className="page quiz-done">
        <div className="celebrate">✅</div>
        <h1>{queue.length ? "Session complete" : "Nothing to review"}</h1>
        {queue.length > 0 && (
          <p className="muted">
            {right} of {queue.length} remembered.
          </p>
        )}
        <a className="btn wide" href={href({ name: "words" })}>
          Back to words
        </a>
        <a className="btn secondary wide" href={href({ name: "library" })}>
          Read a story
        </a>
      </div>
    );
  }

  const e = d[current.key];
  const answer = (correct: boolean) => {
    actions.reviewWord(current.key, correct);
    if (correct) setRight((r) => r + 1);
    setFlipped(false);
    setIndex(index + 1);
  };
  const context = current.context.replace(new RegExp(`\\b${escape(current.word)}\\b`, "i"), "＿＿＿");

  return (
    <div className="page quiz">
      <header className="quiz-head">
        <a className="icon-btn" href={href({ name: "words" })} aria-label="End practice">
          ✕
        </a>
        <span className="muted small">
          {index + 1} / {queue.length}
        </span>
      </header>

      <button className={flipped ? "flashcard flipped" : "flashcard"} onClick={() => setFlipped(true)} aria-live="polite">
        <span className="fc-word" lang="de">
          {e ? (e.g ? `${e.g} ${e.h}` : e.h) : current.word}
        </span>
        {!flipped && <span className="muted small">Do you remember it? Tap to reveal.</span>}
        {flipped && (
          <>
            <span className="fc-gloss">{e ? e.en.join(", ") : "(no dictionary entry)"}</span>
            {e?.pl && <span className="muted small">plural: die {e.pl}</span>}
            <span className="fc-context" lang="de">
              {context}
            </span>
          </>
        )}
      </button>
      <button className="btn secondary" onClick={() => playWord(e, e?.h ?? current.word, rate)}>
        🔊 Listen
      </button>

      {flipped ? (
        <div className="grade">
          <button className="btn bad" onClick={() => answer(false)}>
            Didn't know
          </button>
          <button className="btn good" onClick={() => answer(true)}>
            Knew it
          </button>
        </div>
      ) : (
        <button className="btn wide" onClick={() => setFlipped(true)}>
          Show answer
        </button>
      )}
    </div>
  );
}

function escape(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
