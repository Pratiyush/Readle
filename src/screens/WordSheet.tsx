import { useEffect } from "react";
import { actions, useStore } from "../lib/store";
import { speak } from "../lib/speech";
import type { DictEntry } from "../lib/types";

const POS: Record<string, string> = {
  noun: "noun",
  verb: "verb",
  adjective: "adjective",
  adverb: "adverb",
  article: "article",
  pronoun: "pronoun",
  preposition: "preposition",
  conjunction: "conjunction",
};

export interface Picked {
  word: string;
  key: string | null;
  compound: boolean;
  sentence: string;
  sentenceEn: string;
}

export function WordSheet({ picked, entry, storyId, onClose }: { picked: Picked; entry?: DictEntry; storyId: string; onClose: () => void }) {
  const saveKey = picked.key ?? `free:${picked.word.toLowerCase()}`;
  const saved = useStore((s) => !!s.words[saveKey]);
  const rate = useStore((s) => s.settings.speechRate);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const headword = entry ? (entry.g ? `${entry.g} ${entry.h}` : entry.h) : picked.word;
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" role="dialog" aria-label={`Meaning of ${picked.word}`} onClick={(e) => e.stopPropagation()}>
        <div className="sheet-grip" />
        <div className="sheet-head">
          <div>
            <h2 className="headword">
              {headword}
              <button className="icon-btn" aria-label="Pronounce" onClick={() => speak(entry?.h ?? picked.word, rate)}>
                🔊
              </button>
            </h2>
            <p className="muted small">
              {entry?.ipa && <span className="ipa">/{entry.ipa}/ </span>}
              {entry && (POS[entry.p] ?? entry.p)}
              {entry?.pl && ` · plural: die ${entry.pl}`}
              {entry?.cefr && <span className={`lvl lvl-${entry.cefr}`}>{entry.cefr}</span>}
            </p>
          </div>
          <button className="icon-btn" aria-label="Close" onClick={onClose}>
            ✕
          </button>
        </div>

        {entry ? (
          <>
            {picked.compound && (
              <p className="note">
                <b>{picked.word}</b> is a compound — this is the meaning of its last part, <b>{entry.h}</b>.
              </p>
            )}
            {!picked.compound && picked.word.toLowerCase() !== entry.h.toLowerCase() && (
              <p className="note">
                <b>{picked.word}</b> is a form of <b>{entry.h}</b>.
              </p>
            )}
            <ul className="glosses">
              {entry.en.map((g) => (
                <li key={g}>{g}</li>
              ))}
            </ul>
            {entry.xd && (
              <div className="example">
                <p lang="de">{entry.xd}</p>
                <p className="muted">{entry.xe}</p>
              </div>
            )}
          </>
        ) : (
          <p className="note">No dictionary entry for this word (often a name). The sentence translation below should help.</p>
        )}

        <div className="example in-story">
          <p className="eyebrow">In this story</p>
          <p lang="de">{picked.sentence}</p>
          <p className="muted">{picked.sentenceEn}</p>
        </div>

        <button
          className={saved ? "btn secondary wide" : "btn wide"}
          onClick={() =>
            actions.toggleWord({ key: saveKey, word: entry?.h ?? picked.word, storyId, context: picked.sentence })
          }
        >
          {saved ? "✓ Saved to your words" : "＋ Save to my words"}
        </button>
      </div>
    </div>
  );
}
