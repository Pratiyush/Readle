#!/usr/bin/env python3
"""Compile Readle's bundled content from a Lernle checkout.

    python3 tools/build_content.py ../lernle [out-dir]

Reads the authored stories, lexicon and frequency aliases from Lernle's
`content/` and writes everything the web app loads to `public/content/`:

  stories.json            the library index (no sentence text)
  stories/<slug>.json     one story: sentences, each tokenised and linked to
                          dictionary keys so a tap needs no runtime lemmatiser
  dict.json               every dictionary entry some story links to
  images/<slug>.webp      story illustrations
  audio/<id>.mp3          the word's pronunciation, from Lernle's own clips

Harvested content (Lernle's `harvest/` and `lemmas/de_tobo.jsonl`) is never
read: it is not ours to ship.
"""

from __future__ import annotations

import gzip
import json
import pathlib
import re
import shutil
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "public" / "content"

# Order matters: earlier sources win when two define the same id.
LEXICON_GLOBS = [
    "lemmas/de.jsonl",
    "gap/reauthored_*.jsonl",
    "gap/reenrich_*.json",
    "gap/authored_*.jsonl",
    "gap/curated_*.jsonl",
]
# Readle's own additions, for frequent story words Lernle's deck lacks.
SUPPLEMENT = ROOT / "tools" / "supplement.jsonl"
EXAMPLE_GLOBS = ["gap/examples_*.jsonl"]

TOKEN_RE = re.compile(r"[^\W\d_]+(?:-[^\W\d_]+)*")
ADJ_ENDINGS = ("sten", "stem", "ster", "stes", "ste", "en", "em", "er", "es", "e")
NOUN_ENDINGS = ("en", "es", "n", "s", "e")
# Strong-verb forms the frequency aliases fold onto the wrong lemma.
EXTRA_FORMS = {"stand": "stehen", "standen": "stehen", "aussieht": "aussehen", "sieht": "sehen"}
# Words that pass the compound test but must not be glossed by their last part.
NOT_COMPOUNDS = {
    "deutschland", "deutschlands", "gutenberg", "baumann", "würzburg",  # names
    "lernende", "lernenden", "reisende", "reisenden",  # participles used as nouns, not -ende
    "südwesten", "vorliebe", "kaffeesatz", "rollläden", "charakterzug",  # head misleads
}
POS_RANK = {"noun": 0, "verb": 1, "adjective": 2}


def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s)


def read_rows(base: pathlib.Path, pattern: str):
    for path in sorted(base.glob(pattern)):
        text = path.read_text(encoding="utf-8")
        if path.suffix == ".json":
            yield from json.loads(text)
        else:
            for line in text.splitlines():
                if line.strip():
                    yield json.loads(line)


def load_lexicon(content: pathlib.Path) -> dict[str, dict]:
    rejected = set()
    decisions = content / "review" / "decisions.jsonl"
    if decisions.exists():
        for line in decisions.read_text(encoding="utf-8").splitlines():
            if line.strip():
                row = json.loads(line)
                if row.get("action") == "reject":
                    rejected.add(row["id"])
                elif row.get("action") in ("accept", "approve"):
                    rejected.discard(row["id"])

    lex: dict[str, dict] = {}
    for pattern in LEXICON_GLOBS:
        for row in read_rows(content, pattern):
            if row["id"] in lex or row["id"] in rejected or not row.get("en"):
                continue
            lex[row["id"]] = row
    for row in read_rows(SUPPLEMENT.parent, SUPPLEMENT.name):
        lex.setdefault(row["id"], row)
    for pattern in EXAMPLE_GLOBS:
        for row in read_rows(content, pattern):
            entry = lex.get(row["id"])
            if entry and not entry.get("example_de"):
                entry["example_de"] = row["example_de"]
                entry["example_en"] = row["example_en"]
    ipa_path = content / "lemmas" / "ipa.json"
    if ipa_path.exists():
        for key, ipa in json.loads(ipa_path.read_text(encoding="utf-8")).items():
            if key in lex and not lex[key].get("ipa"):
                lex[key]["ipa"] = ipa
    return lex


def build_surface_index(content: pathlib.Path, lex: dict[str, dict]):
    """lowercase surface form → candidate lemma ids."""
    index: dict[str, list[str]] = {}

    def add(form: str, lid: str):
        form = nfc(form).lower()
        ids = index.setdefault(form, [])
        if lid not in ids:
            ids.append(lid)

    for lid, row in lex.items():
        add(row["headword"], lid)
        if row.get("plural"):
            add(row["plural"], lid)
    for row in read_rows(content, "grammar/conjugation.jsonl"):
        lid = row.get("lemma_id")
        if lid in lex:
            for form in row["forms"].values():
                # "rufe an" → also index the finite part "rufe"
                add(form.split()[0], lid)
    for form, headword in EXTRA_FORMS.items():
        for lid, row in lex.items():
            if row["headword"] == headword:
                add(form, lid)
    return index


def load_aliases(content: pathlib.Path) -> dict[str, str]:
    aliases = {}
    with gzip.open(content / "freq" / "de_form_alias.tsv.gz", "rt", encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            form, _, lemma = line.rstrip("\n").partition("\t")
            if lemma:
                aliases[nfc(form)] = nfc(lemma)
    return aliases


class Resolver:
    def __init__(self, lex, index, aliases):
        self.lex, self.index, self.aliases = lex, index, aliases

    def _pick(self, ids: list[str], capitalised: bool) -> str:
        def score(lid):
            pos = self.lex[lid].get("pos")
            noun_match = (pos == "noun") == capitalised
            return (not noun_match, POS_RANK.get(pos, 3), self.lex[lid].get("freq_rank") or 99999)
        return min(ids, key=score)

    def _is_modifier(self, head: str) -> bool:
        """The front part of a compound must itself be a word (Haus-tür, Küchen-tisch, Königs-haus,
        Schul-tag), so names and plain nouns are not split at random (Ter-rasse, Rönt-gen)."""
        forms = {head, head + "e", head + "en"}
        for link in ("s", "es", "n", "en", "e", "er"):
            if head.endswith(link) and len(head) - len(link) >= 3:
                forms.add(head[: -len(link)])
        return any(f in self.index for f in forms)

    def resolve(self, word: str, sentence_initial: bool) -> tuple[str | None, bool]:
        """Returns (lemma id, is_compound_head)."""
        low = word.lower()
        capitalised = word[:1].isupper() and not sentence_initial
        candidates = [low]
        alias = self.aliases.get(low)
        if alias:
            candidates.append(alias)
        for end in ADJ_ENDINGS + NOUN_ENDINGS:
            if low.endswith(end) and len(low) - len(end) >= 3:
                candidates.append(low[: -len(end)])
        # comparatives: schöner → schön, größer → groß
        if low.endswith("er") and len(low) > 5:
            candidates.append(low[:-2].replace("ä", "a").replace("ö", "o").replace("ü", "u"))
        # past participles of weak verbs: gemacht → machen
        if low.startswith("ge") and low.endswith("t") and len(low) > 5:
            candidates.append(low[2:-1] + "en")
        lower_mid = not word[:1].isupper()
        for cand in candidates:
            ids = self.index.get(cand) or []
            if lower_mid:
                # German nouns are always capitalised: "weg" is never "Weg".
                ids = [lid for lid in ids if self.lex[lid].get("pos") != "noun"]
            if ids:
                return self._pick(ids, capitalised), False
        # compound nouns: resolve the head (Haustür → Tür)
        if word[:1].isupper() and len(low) > 6 and low not in NOT_COMPOUNDS:
            for i in range(3, len(low) - 2):
                if not self._is_modifier(low[:i]):
                    continue
                tail = low[i:]
                ids = self.index.get(tail) or self.index.get(self.aliases.get(tail, ""))
                if ids:
                    nouns = [lid for lid in ids if self.lex[lid].get("pos") == "noun"]
                    if nouns:
                        return self._pick(nouns, True), True
        return None, False


def tokenise(text: str, resolver: Resolver, used: set[str]):
    tokens, pos, first = [], 0, True
    for m in TOKEN_RE.finditer(text):
        if m.start() > pos:
            tokens.append(text[pos : m.start()])
        word = m.group(0)
        lid, compound = resolver.resolve(word, first)
        first = False
        if lid:
            used.add(lid)
            # A third element marks a compound linked through its head noun.
            tokens.append([word, lid, 1] if compound else [word, lid])
        else:
            tokens.append([word])
        pos = m.end()
    if pos < len(text):
        tokens.append(text[pos:])
    return tokens


def dict_entry(row: dict) -> dict:
    entry = {"h": row["headword"], "p": row.get("pos", "other"), "en": row["en"]}
    for src, dst in (("gender", "g"), ("plural", "pl"), ("ipa", "ipa"), ("cefr", "cefr"),
                     ("example_de", "xd"), ("example_en", "xe")):
        if row.get(src):
            entry[dst] = row[src]
    return entry


ASCII = str.maketrans({"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss", "Ä": "Ae", "Ö": "Oe", "Ü": "Ue"})


def copy_word_audio(clip_dir: pathlib.Path, dictionary: dict[str, dict]) -> int:
    """Copy Lernle's pronunciation clip for every linked entry that has one, and record its path
    in the entry as "au". The clips are Lernle's own ElevenLabs recordings (64 kbps mono encodes
    of content/audio/masters, see lernle/tools/gen_audio_eleven.py); nothing here calls a TTS API.
    File names are made ASCII (de.realität.n → de.realitaet.n), which is safe in URLs and in
    Flutter asset paths alike."""
    if not clip_dir.is_dir():
        print(f"word audio  none: {clip_dir} not found")
        return 0
    (OUT / "audio").mkdir()
    taken: set[str] = set()
    n = 0
    for lid, entry in dictionary.items():
        src = clip_dir / f"{lid}.mp3"
        if not src.is_file():
            continue
        name = re.sub(r"[^A-Za-z0-9._-]", "_", lid.translate(ASCII))
        while name in taken:
            name += "_"
        taken.add(name)
        shutil.copyfile(src, OUT / "audio" / f"{name}.mp3")
        entry["au"] = f"audio/{name}.mp3"
        n += 1
    return n


def main() -> None:
    global OUT
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    content = pathlib.Path(sys.argv[1]).resolve() / "content"
    if len(sys.argv) == 3:  # optional output dir, for dry runs
        OUT = pathlib.Path(sys.argv[2]).resolve()
    lex = load_lexicon(content)
    resolver = Resolver(lex, build_surface_index(content, lex), load_aliases(content))

    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "stories").mkdir(parents=True)
    (OUT / "images").mkdir()

    used: set[str] = set()
    library, words, linked = [], 0, 0
    for path in sorted((content / "stories" / "de").glob("*.json")):
        story = json.loads(path.read_text(encoding="utf-8"))
        slug = story["id"].removeprefix("de.story.")
        sentences = []
        for s in story["sentences"]:
            toks = tokenise(nfc(s["de"]), resolver, used)
            words += sum(1 for t in toks if isinstance(t, list))
            linked += sum(1 for t in toks if isinstance(t, list) and len(t) >= 2)
            sentences.append({"de": nfc(s["de"]), "en": s["en"], "t": toks})
        image = content / "stories" / "images" / story.get("image", "")
        has_image = image.is_file()
        if has_image:
            shutil.copyfile(image, OUT / "images" / f"{slug}.webp")
        text_words = sum(len(TOKEN_RE.findall(s["de"])) for s in story["sentences"])
        meta = {
            "id": slug,
            "title": nfc(story["title"]),
            "level": story["cefr"],
            "collection": story.get("collection", "fiction"),
            "publishedAt": story.get("publishedAt", ""),
            "image": f"images/{slug}.webp" if has_image else None,
            "teaser": nfc(story["sentences"][0]["de"]),
            "teaserEn": story["sentences"][0]["en"],
            "words": text_words,
            "minutes": max(1, round(text_words / 120)),
        }
        library.append(meta)
        (OUT / "stories" / f"{slug}.json").write_text(
            json.dumps({**meta, "sentences": sentences}, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )

    library.sort(key=lambda m: (m["publishedAt"], m["id"]), reverse=True)
    (OUT / "stories.json").write_text(
        json.dumps(library, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    dictionary = {lid: dict_entry(lex[lid]) for lid in sorted(used)}
    clips = copy_word_audio(content.parent / "app" / "assets" / "audio" / "de", dictionary)
    (OUT / "dict.json").write_text(
        json.dumps(dictionary, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    print(f"stories     {len(library)}")
    print(f"word audio  {clips} clips for {len(dictionary)} entries")
    print(f"lexicon     {len(lex)} entries, {len(dictionary)} linked from stories")
    print(f"word tokens {words}, {linked} linked ({100 * linked / max(words, 1):.1f}%)")


if __name__ == "__main__":
    main()
