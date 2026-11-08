# Readle Deutsch

Learn German by reading short stories — a [Readle](https://play.google.com/store/apps/details?id=com.langster.languages)-style
reader built on the stories and dictionary from [Lernle](https://github.com/Pratiyush/lernle).

It's an installable web app (PWA): it works on phones and desktops, offline once
loaded, with no account and no ads.

## Features

- **107 illustrated stories**, levels A1–B2, in three collections (fiction, culture, facts).
  Filter by level, collection or unread, or search.
- **Story of the day** — the same pick all day, preferring stories you haven't read.
- **Tap any word** for its meaning: article and plural for nouns, IPA, CEFR level, an example
  sentence, and a note when the word is an inflected form ("gibt is a form of geben") or a compound.
  96% of the words in the stories link to a dictionary entry.
- **Sentence translations** — tap ⇄ after a sentence, or **EN** to show them all.
- **Listen** — the story is read aloud sentence by sentence with the current one highlighted,
  using the device's German voice. Single words can be played too.
- **Comprehension quiz** after every story: word meanings plus sentence translations.
- **My words** — save words while reading, then review them as flashcards with spaced repetition
  (Leitner boxes: 1, 3, 7, 14, 30, 60 days).
- **Progress** — day streak, daily goal, stories read per level, words saved and mastered.
- Adjustable text size, light/dark theme, speech speed.

## Run it

```sh
npm install
npm run dev        # http://localhost:5173
npm test           # unit + content integrity tests
npm run build      # static site in dist/
```

Pushing to `main` builds and deploys to GitHub Pages (`.github/workflows/ci.yml`; enable Pages with
source "GitHub Actions" in the repository settings).

## Content

Everything the app reads lives in `public/content/` and is compiled from a Lernle checkout:

```sh
git clone https://github.com/Pratiyush/lernle ../lernle
npm run content    # python3 tools/build_content.py ../lernle
```

The build script tokenises every sentence and links each word to a dictionary entry ahead of time,
so tapping a word is a lookup with no runtime lemmatiser. Lookups go through the exact headword,
noun plurals, verb conjugation tables, Lernle's frequency form→lemma aliases, inflection endings and,
for compounds, the head noun. `tools/supplement.jsonl` adds frequent story words Lernle's deck lacks.

Sources used: `content/stories/de` (stories + illustrations), `content/lemmas/de.jsonl`,
`content/gap/{reauthored,reenrich,authored,curated,examples}_*`, `content/grammar/conjugation.jsonl`,
`content/freq/de_form_alias.tsv.gz` (derived from MIT-licensed FrequencyWords). Lernle's harvested
material (`harvest/`, `lemmas/de_tobo.jsonl`) is deliberately **not** used.

The German text is machine-assisted and marked `review: pending` in Lernle until a native speaker
has checked it.
