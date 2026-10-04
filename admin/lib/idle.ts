"use client";

import { useEffect, useSyncExternalStore } from "react";

const LAST = "panel.lastActive";
const FLAG = "panel.idleSignedOut";

// Storage can be off — a private window, blocked site data — and the panel
// must work without it.
const read = (s: Storage | undefined, k: string) => {
  try {
    return s?.getItem(k) ?? null;
  } catch {
    return null;
  }
};
const write = (s: Storage | undefined, k: string, v: string | null) => {
  try {
    if (v == null) s?.removeItem(k);
    else s?.setItem(k, v);
  } catch {}
};

/**
 * Signs out after [minutes] with nothing done — no click, key or scroll in
 * any of the panel's tabs, which share when they were last used — so a
 * panel left open on a shared computer closes itself.
 */
export function useIdleSignOut(signOut: () => Promise<void>, minutes = 30) {
  useEffect(() => {
    const limit = minutes * 60_000;
    let last = Date.now();
    let written = 0;
    const touch = () => {
      last = Date.now();
      if (last - written > 15_000) {
        written = last;
        write(globalThis.localStorage, LAST, String(last));
      }
    };
    const check = () => {
      const shared = Math.max(last, Number(read(globalThis.localStorage, LAST)) || 0);
      if (Date.now() - shared > limit) {
        write(globalThis.sessionStorage, FLAG, "1");
        void signOut();
      }
    };
    const seen = () => document.visibilityState === "visible" && check();
    touch();
    const events = ["pointerdown", "keydown", "wheel", "touchstart"] as const;
    events.forEach((e) => window.addEventListener(e, touch, { passive: true }));
    document.addEventListener("visibilitychange", seen);
    const timer = setInterval(check, 30_000);
    return () => {
      events.forEach((e) => window.removeEventListener(e, touch));
      document.removeEventListener("visibilitychange", seen);
      clearInterval(timer);
    };
  }, [signOut, minutes]);
}

/** Whether the last sign-out here was for being idle; [clear] forgets it. */
export function useSignedOutIdle(): [boolean, () => void] {
  const idle = useSyncExternalStore(
    () => () => {},
    () => read(globalThis.sessionStorage, FLAG) === "1",
    () => false,
  );
  return [idle, () => write(globalThis.sessionStorage, FLAG, null)];
}
