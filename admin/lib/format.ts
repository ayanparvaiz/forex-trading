import { Timestamp } from "firebase/firestore";

/** A Firestore time — a Timestamp, or an ISO string from older writes. */
export function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === "string" || typeof v === "number") {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/** "5m ago", "3h ago", "2d ago", then the date. */
export function timeAgo(v: unknown, now = Date.now()): string {
  const d = toDate(v);
  if (!d) return "—";
  const s = Math.max(0, Math.round((now - d.getTime()) / 1000));
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  if (s < 7 * 86400) return `${Math.floor(s / 86400)}d ago`;
  return dateLabel(d);
}

export function dateLabel(v: unknown): string {
  const d = toDate(v);
  return d ? d.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }) : "—";
}

export function dateTime(v: unknown): string {
  const d = toDate(v);
  return d
    ? d.toLocaleString("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })
    : "—";
}

export const count = (n: unknown) =>
  typeof n === "number" ? n.toLocaleString("en-US") : "—";

/** +1.25R, −0.50R. */
export function rText(n: unknown): string {
  if (typeof n !== "number") return "—";
  const sign = n > 0 ? "+" : n < 0 ? "−" : "";
  return `${sign}${Math.abs(n).toFixed(2)}R`;
}

export const pad2 = (n: number) => String(n).padStart(2, "0");
