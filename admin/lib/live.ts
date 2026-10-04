"use client";

import { collection, onSnapshot, query, where } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

/** How many documents in [name] are open, kept up to date; null when not readable. */
function useOpen(name: string, on = true): number | null {
  const [open, setOpen] = useState<number | null>(null);
  useEffect(() => {
    if (!on) return;
    return onSnapshot(
      query(collection(db, name), where("status", "==", "open")),
      (snap) => setOpen(snap.size),
      (e) => console.warn(`open ${name}:`, e.message),
    );
  }, [name, on]);
  return on ? open : null;
}

/**
 * How many reports are waiting, kept up to date as people report things —
 * and in the browser tab's title, so a new one shows from another tab.
 */
export function useOpenReports(): number | null {
  const open = useOpen("reports");
  useEffect(() => {
    const base = document.title.replace(/^\(\d+\) /, "");
    document.title = open ? `(${open}) ${base}` : base;
  }, [open]);
  return open;
}

/** Messages to the admins and password requests waiting — for those who may read them. */
export function useOpenHelp(on: boolean): number | null {
  const messages = useOpen("support", on);
  const requests = useOpen("helpRequests", on);
  return messages == null && requests == null ? null : (messages ?? 0) + (requests ?? 0);
}
