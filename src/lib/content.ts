import type { Dictionary, Story, StoryMeta } from "./types";

const base = `${import.meta.env.BASE_URL}content/`;
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

export const loadLibrary = () => load<StoryMeta[]>("stories.json");
export const loadStory = (id: string) => load<Story>(`stories/${encodeURIComponent(id)}.json`);
export const loadDictionary = () => load<Dictionary>("dict.json");
export const imageUrl = (path: string) => base + path;
