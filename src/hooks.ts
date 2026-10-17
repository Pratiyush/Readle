import { useEffect, useState } from "react";

export type Async<T> = { status: "loading" } | { status: "error"; error: string } | { status: "ready"; value: T };

export function useAsync<T>(load: () => Promise<T>, deps: unknown[]): Async<T> {
  const [state, setState] = useState<Async<T>>({ status: "loading" });
  useEffect(() => {
    let live = true;
    setState({ status: "loading" });
    load().then(
      (value) => live && setState({ status: "ready", value }),
      (e: unknown) => live && setState({ status: "error", error: String(e) }),
    );
    return () => {
      live = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return state;
}
