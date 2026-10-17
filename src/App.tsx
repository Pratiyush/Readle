import { useEffect } from "react";
import { href, useRoute, type Route } from "./router";
import { useStore } from "./lib/store";
import { isDue } from "./lib/srs";
import { dayKey } from "./lib/dates";
import { Library } from "./screens/Library";
import { Reader } from "./screens/Reader";
import { Quiz } from "./screens/Quiz";
import { Words } from "./screens/Words";
import { Practice } from "./screens/Practice";
import { Me } from "./screens/Me";

export function App() {
  const route = useRoute();
  const settings = useStore((s) => s.settings);
  const due = useStore((s) => Object.values(s.words).filter((w) => isDue(w.card, dayKey())).length);

  useEffect(() => {
    const root = document.documentElement;
    if (settings.theme === "system") delete root.dataset.theme;
    else root.dataset.theme = settings.theme;
    root.style.setProperty("--reader-scale", String(settings.fontScale));
  }, [settings.theme, settings.fontScale]);

  const immersive = route.name === "story" || route.name === "quiz" || route.name === "practice";
  return (
    <div className="app">
      <main className={immersive ? "immersive" : "with-nav"}>{screen(route)}</main>
      {!immersive && (
        <nav className="tabbar" aria-label="Main">
          <Tab to={{ name: "library" }} active={route.name === "library"} icon="📚" label="Stories" />
          <Tab to={{ name: "words" }} active={route.name === "words"} icon="🗂️" label="Words" badge={due} />
          <Tab to={{ name: "me" }} active={route.name === "me"} icon="🔥" label="Progress" />
        </nav>
      )}
    </div>
  );
}

function screen(route: Route) {
  switch (route.name) {
    case "story":
      return <Reader key={route.id} id={route.id} />;
    case "quiz":
      return <Quiz key={route.id} id={route.id} />;
    case "words":
      return <Words />;
    case "practice":
      return <Practice />;
    case "me":
      return <Me />;
    default:
      return <Library />;
  }
}

function Tab(props: { to: Route; active: boolean; icon: string; label: string; badge?: number }) {
  return (
    <a href={href(props.to)} className={props.active ? "tab active" : "tab"} aria-current={props.active ? "page" : undefined}>
      <span className="tab-icon" aria-hidden>
        {props.icon}
        {!!props.badge && <span className="badge">{props.badge > 99 ? "99+" : props.badge}</span>}
      </span>
      {props.label}
    </a>
  );
}
