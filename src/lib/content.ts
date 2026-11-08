import type { DictEntry, Dictionary, Story, StoryMeta } from "./types";

/**
 * Everything the app reads — stories, their pictures and the dictionary — goes through one
 * ContentSource. Today that is the bundled `public/content/` folder; the shared german-content
 * CDN (stories, daily articles, word sets) can be added later as another source, or a source that
 * layers live packs over the bundled one, without touching any screen.
 */
export interface ContentSource {
  library(): Promise<StoryMeta[]>;
  story(id: string): Promise<Story>;
  dictionary(): Promise<Dictionary>;
  imageUrl(path: string): string;
  /** The recorded pronunciation of an entry, or null when there is none (callers fall back to TTS). */
  audioUrl(entry: DictEntry | undefined): string | null;
}

/** Static JSON files under `base`, fetched once per path and memoised (failures are retried). */
export function bundledSource(base = `${import.meta.env.BASE_URL}content/`): ContentSource {
  const cache = new Map<string, Promise<unknown>>();
  function load<T>(path: string): Promise<T> {
    let hit = cache.get(path);
    if (!hit) {
      hit = fetch(base + path).then((r) => {
        if (!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
        return r.json();
      });
      hit.catch(() => cache.delete(path));
      cache.set(path, hit);
    }
    return hit as Promise<T>;
  }
  return {
    library: () => load<StoryMeta[]>("stories.json"),
    story: (id) => load<Story>(`stories/${encodeURIComponent(id)}.json`),
    dictionary: () => load<Dictionary>("dict.json"),
    imageUrl: (path) => base + path,
    audioUrl: (entry) => (entry?.au ? base + entry.au : null),
  };
}

let source: ContentSource = bundledSource();

/** Swap the source (tests, or the CDN source once it exists). */
export function setContentSource(next: ContentSource): void {
  source = next;
}

export const loadLibrary = () => source.library();
export const loadStory = (id: string) => source.story(id);
export const loadDictionary = () => source.dictionary();
export const imageUrl = (path: string) => source.imageUrl(path);
export const audioUrl = (entry: DictEntry | undefined) => source.audioUrl(entry);
