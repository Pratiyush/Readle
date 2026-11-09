import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { imageUrl, loadDictionary, loadStory } from "../lib/content";
import { useAsync } from "../hooks";
import { actions, getState, useStore } from "../lib/store";
import { speak, stopSpeaking, useGermanVoice } from "../lib/speech";
import type { Dictionary, Story } from "../lib/types";
import { glue } from "../lib/glue";
import { go, href } from "../router";
import { WordSheet, type Picked } from "./WordSheet";

const SCALES = [0.9, 1, 1.15, 1.3, 1.5];

export function Reader({ id }: { id: string }) {
  const data = useAsync(() => Promise.all([loadStory(id), loadDictionary()]), [id]);
  if (data.status === "loading") return <p className="muted center pad">Loading…</p>;
  if (data.status === "error")
    return (
      <div className="page center">
        <p className="muted">This story couldn't be loaded.</p>
        <a className="btn" href={href({ name: "library" })}>
          Back to stories
        </a>
      </div>
    );
  const [story, dict] = data.value;
  return <ReaderView story={story} dict={dict} />;
}

function ReaderView({ story, dict }: { story: Story; dict: Dictionary }) {
  const settings = useStore((s) => s.settings);
  const saved = useStore((s) => s.words);
  const isRead = useStore((s) => !!s.read[story.id]);
  const tipSeen = useStore((s) => s.wordTipSeen);
  const canSpeak = useGermanVoice();
  const [shown, setShown] = useState<Set<number>>(new Set());
  const [allShown, setAllShown] = useState(false);
  const [picked, setPicked] = useState<Picked | null>(null);
  const [playing, setPlaying] = useState<number | null>(null);
  const [progress, setProgress] = useState(0);
  const playToken = useRef(0);
  const units = useMemo(() => story.sentences.map((s) => glue(s.t)), [story]);

  // Reopen where the learner left off, and remember it for the library's "Continue reading".
  useEffect(() => {
    const s = getState();
    actions.openStory(story.id);
    const reached = s.progress[story.id] ?? 0;
    if (!s.read[story.id] && reached > 0) document.getElementById(`s${reached}`)?.scrollIntoView({ block: "center" });
  }, [story.id]);

  useEffect(() => {
    const last = story.sentences.length - 1;
    const on = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const p = max > 0 ? Math.min(1, window.scrollY / max) : 1;
      setProgress(p);
      if (window.scrollY > 0) actions.setProgress(story.id, Math.round(p * last));
    };
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, [story]);

  // Leaving the reader must silence it: bump the token first, because cancelling fires the
  // utterance's end/error handler, which would otherwise go on to speak the next sentence.
  useEffect(
    () => () => {
      playToken.current++;
      stopSpeaking();
    },
    [],
  );

  const play = useCallback(
    (from: number) => {
      stopSpeaking();
      const token = ++playToken.current;
      const step = (i: number) => {
        if (token !== playToken.current || i >= story.sentences.length) {
          if (token === playToken.current) setPlaying(null);
          return;
        }
        setPlaying(i);
        actions.setProgress(story.id, i);
        document.getElementById(`s${i}`)?.scrollIntoView({ block: "center", behavior: "smooth" });
        speak(story.sentences[i].de, settings.speechRate, () => step(i + 1));
      };
      step(from);
    },
    [story, settings.speechRate],
  );

  const stop = () => {
    playToken.current++;
    stopSpeaking();
    setPlaying(null);
  };

  const toggleSentence = (i: number) =>
    setShown((prev) => {
      const next = new Set(prev);
      if (next.has(i)) next.delete(i);
      else next.add(i);
      return next;
    });

  const cycleFont = () => {
    const i = SCALES.indexOf(settings.fontScale);
    actions.updateSettings({ fontScale: SCALES[(i + 1) % SCALES.length] });
  };

  const translateButton = (i: number) => (
    <button className="tr-btn" onClick={() => toggleSentence(i)} aria-label={`Translate sentence ${i + 1}`} aria-expanded={allShown || shown.has(i)}>
      ⇄
    </button>
  );

  const finish = () => {
    stop();
    actions.setProgress(story.id, story.sentences.length - 1);
    actions.finishStory(story.id);
    go({ name: "quiz", id: story.id });
  };

  return (
    <div className="reader">
      <header className="reader-bar">
        <a className="icon-btn" href={href({ name: "library" })} aria-label="Back to stories">
          ←
        </a>
        <div className="reader-bar-actions">
          {canSpeak && (
            <button className="icon-btn" onClick={() => (playing === null ? play(0) : stop())} aria-label={playing === null ? "Listen" : "Stop"}>
              {playing === null ? "▶︎" : "■"}
            </button>
          )}
          <button className={allShown ? "icon-btn on" : "icon-btn"} onClick={() => setAllShown(!allShown)} aria-label="Show all translations" aria-pressed={allShown}>
            EN
          </button>
          <button className="icon-btn" onClick={cycleFont} aria-label="Text size">
            Aa
          </button>
        </div>
        <div className="read-progress" style={{ transform: `scaleX(${progress})` }} />
      </header>

      {story.image && <img className="reader-hero" src={imageUrl(story.image)} alt="" />}
      <article className="reader-body">
        <p className="meta">
          <span className={`lvl lvl-${story.level}`}>{story.level}</span> {story.minutes} min read · {story.words} words
        </p>
        <h1 lang="de">{story.title}</h1>
        {tipSeen ? (
          <p className="muted small tip">Tap any word for its meaning. Tap ⇄ for a sentence translation.</p>
        ) : (
          // First run: the one thing to learn about this app, until the first tap.
          <p className="tip first-tip" data-testid="word-tip">
            <span aria-hidden>👆</span> Tap any word to hear it and see what it means. Tap ⇄ to translate a sentence.
          </p>
        )}

        <div className="story-text" lang="de">
          {story.sentences.map((s, i) => (
            <span key={i} id={`s${i}`} className={playing === i ? "sentence playing" : "sentence"}>
              {units[i].map((unit, j, row) => {
                if (typeof unit === "string") return unit;
                const [word, key, compound] = unit.tok;
                const savedHere = (key && saved[key]) || saved[`free:${word.toLowerCase()}`];
                const last = j === row.length - 1;
                return (
                  <span key={j} className="nw">
                    {unit.pre}
                    <button
                      className={`w${key ? "" : " w-unknown"}${savedHere ? " w-saved" : ""}`}
                      onClick={() => {
                        if (playing !== null) stop(); // the word's own audio replaces the story reading
                        actions.markWordTipSeen();
                        setPicked({ word, key: key ?? null, compound: compound === 1, sentence: s.de, sentenceEn: s.en });
                      }}
                    >
                      {word}
                    </button>
                    {unit.post}
                    {last && "\u00a0"}
                    {last && translateButton(i)}
                  </span>
                );
              })}
              {typeof units[i].at(-1) === "string" && <> {translateButton(i)}</>}
              {(allShown || shown.has(i)) && (
                <span className="translation" lang="en">
                  <span className="tr-text">{s.en}</span>
                  {canSpeak && (
                    <button className="tr-btn listen-from" onClick={() => play(i)} aria-label={`Listen from sentence ${i + 1}`} title="Listen from here">
                      {playing === i ? "♪" : "🔊"}
                    </button>
                  )}
                </span>
              )}{" "}
            </span>
          ))}
        </div>

        <div className="finish">
          <button className="btn wide" onClick={finish}>
            {isRead ? "Take the quiz again" : "Finish & take the quiz"}
          </button>
          <a className="btn secondary wide" href={href({ name: "library" })}>
            Back to stories
          </a>
        </div>
      </article>

      {picked && <WordSheet picked={picked} entry={picked.key ? dict[picked.key] : undefined} storyId={story.id} onClose={() => setPicked(null)} />}
    </div>
  );
}
