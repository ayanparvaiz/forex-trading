"use client";

import { collection, onSnapshot, query, where } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "./firebase";

/**
 * How many reports are waiting, kept up to date as people report things —
 * and in the browser tab's title, so a new one shows from another tab.
 */
export function useOpenReports(): number | null {
  const [open, setOpen] = useState<number | null>(null);
  useEffect(
    () =>
      onSnapshot(
        query(collection(db, "reports"), where("status", "==", "open")),
        (snap) => setOpen(snap.size),
        (e) => console.warn("open reports:", e.message),
      ),
    [],
  );
  useEffect(() => {
    const base = document.title.replace(/^\(\d+\) /, "");
    document.title = open ? `(${open}) ${base}` : base;
  }, [open]);
  return open;
}
