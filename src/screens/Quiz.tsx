import { useMemo, useState } from "react";
import { loadDictionary, loadStory } from "../lib/content";
import { useAsync } from "../hooks";
import { buildQuiz, praise } from "../lib/quiz";
import { actions, streak, useStore } from "../lib/store";
import { href } from "../router";
import type { Dictionary, Story } from "../lib/types";

export function Quiz({ id }: { id: string }) {
  const data = useAsync(() => Promise.all([loadStory(id), loadDictionary()]), [id]);
  if (data.status !== "ready") return <p className="muted center pad">{data.status === "error" ? "Couldn't load the quiz." : "Loading…"}</p>;
  return <QuizView story={data.value[0]} dict={data.value[1]} />;
}

function QuizView({ story, dict }: { story: Story; dict: Dictionary }) {
  // A fresh seed per visit, so retaking the quiz isn't a memory test of the last attempt.
  const [seed] = useState(() => `${story.id}:${Date.now()}`);
  const questions = useMemo(() => buildQuiz(story, dict, seed), [story, dict, seed]);
  const [index, setIndex] = useState(0);
  const [chosen, setChosen] = useState<number | null>(null);
  const [correct, setCorrect] = useState(0);
  const days = useStore((s) => s.activeDays);

  const done = index >= questions.length;
  const q = questions[index];

  const choose = (i: number) => {
    if (chosen !== null) return;
    setChosen(i);
    const right = i === q.answer;
    if (right) setCorrect((c) => c + 1);
    if (index === questions.length - 1) actions.recordQuiz(story.id, (correct + (right ? 1 : 0)) / questions.length);
  };

  if (done || !questions.length) {
    const pct = questions.length ? Math.round((100 * correct) / questions.length) : 100;
    const [emoji, headline] = praise(pct);
    return (
      <div className="page quiz-done">
        <div className="celebrate">{emoji}</div>
        <h1>{headline}</h1>
        <p className="muted">You finished “{story.title}”.</p>
        <div className="stat-row">
          <div className="stat">
            <b>{pct}%</b>
            <span>quiz score</span>
          </div>
          <div className="stat">
            <b>🔥 {streak(days)}</b>
            <span>day streak</span>
          </div>
        </div>
        <a className="btn wide" href={href({ name: "library" })}>
          Next story
        </a>
        <a className="btn secondary wide" href={href({ name: "words" })}>
          Review my words
        </a>
      </div>
    );
  }

  return (
    <div className="page quiz">
      <header className="quiz-head">
        <a className="icon-btn" href={href({ name: "library" })} aria-label="Close quiz">
          ✕
        </a>
        <div className="dots">
          {questions.map((_, i) => (
            <span key={i} className={i < index ? "dot past" : i === index ? "dot now" : "dot"} />
          ))}
        </div>
      </header>

      <p className="eyebrow">{q.kind === "word" ? "What does this word mean?" : "What does this sentence mean?"}</p>
      <h2 className={q.kind === "word" ? "quiz-word" : "quiz-sentence"} lang="de">
        {q.prompt}
      </h2>
      {q.promptSub && (
        <p className="muted quiz-context" lang="de">
          “{q.promptSub}”
        </p>
      )}

      <div className="options">
        {q.options.map((o, i) => {
          let cls = "option";
          if (chosen !== null) {
            if (i === q.answer) cls += " right";
            else if (i === chosen) cls += " wrong";
          }
          return (
            <button key={i} className={cls} onClick={() => choose(i)} disabled={chosen !== null && i !== chosen && i !== q.answer}>
              {o}
            </button>
          );
        })}
      </div>

      {chosen !== null && (
        <div className={chosen === q.answer ? "feedback good" : "feedback bad"}>
          <b>{chosen === q.answer ? "Richtig!" : "Not quite."}</b>
          <button
            className="btn"
            onClick={() => {
              setChosen(null);
              setIndex(index + 1);
            }}
          >
            {index === questions.length - 1 ? "See results" : "Continue"}
          </button>
        </div>
      )}
    </div>
  );
}
