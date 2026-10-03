"use client";

import { useEffect, useRef, useState } from "react";

type Result<T> = { for: string; data?: T; error?: unknown };

/**
 * Loads [fn] on mount, again whenever [key] changes, and on reload(). While
 * reloading, the last answer stays on screen.
 */
export function useLoad<T>(fn: () => Promise<T>, key = "") {
  const [round, setRound] = useState(0);
  const want = `${key}#${round}`;
  const [result, setResult] = useState<Result<T> | null>(null);
  const latest = useRef(fn);
  useEffect(() => {
    latest.current = fn;
  });

  useEffect(() => {
    let live = true;
    latest.current().then(
      (data) => live && setResult({ for: want, data }),
      (error) => live && setResult({ for: want, error }),
    );
    return () => {
      live = false;
    };
  }, [want]);

  const loading = result?.for !== want;
  return {
    data: result?.data ?? null,
    error: loading ? null : (result?.error ?? null),
    loading,
    reload: () => setRound((r) => r + 1),
  };
}
