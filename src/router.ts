import { useEffect, useState } from "react";

export type Route =
  | { name: "library" }
  | { name: "story"; id: string }
  | { name: "quiz"; id: string }
  | { name: "words" }
  | { name: "practice" }
  | { name: "me" };

export function parse(hash: string): Route {
  const parts = hash.replace(/^#\/?/, "").split("/").filter(Boolean).map(decodeURIComponent);
  if (parts[0] === "story" && parts[1]) return parts[2] === "quiz" ? { name: "quiz", id: parts[1] } : { name: "story", id: parts[1] };
  if (parts[0] === "words") return parts[1] === "practice" ? { name: "practice" } : { name: "words" };
  if (parts[0] === "me") return { name: "me" };
  return { name: "library" };
}

export function href(r: Route): string {
  switch (r.name) {
    case "story":
      return `#/story/${encodeURIComponent(r.id)}`;
    case "quiz":
      return `#/story/${encodeURIComponent(r.id)}/quiz`;
    case "words":
      return "#/words";
    case "practice":
      return "#/words/practice";
    case "me":
      return "#/me";
    default:
      return "#/";
  }
}

export const go = (r: Route) => (window.location.hash = href(r));

export function useRoute(): Route {
  const [route, setRoute] = useState(() => parse(window.location.hash));
  useEffect(() => {
    const on = () => {
      setRoute(parse(window.location.hash));
      window.scrollTo(0, 0);
    };
    window.addEventListener("hashchange", on);
    return () => window.removeEventListener("hashchange", on);
  }, []);
  return route;
}
