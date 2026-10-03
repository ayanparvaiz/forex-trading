import { toDate } from "./format";

type Cell = string | number | boolean | null | undefined;

/** One cell, quoted when it must be, and never read as a formula. */
function cell(v: Cell): string {
  let s = v == null ? "" : String(v);
  // A spreadsheet runs a cell starting with these as a formula — but a
  // number, -5.12 say, stays a number.
  if (typeof v === "string" && /^[=+\-@\t\r]/.test(s) && !/^-?\d+(\.\d+)?$/.test(s)) s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
}

/** An ISO-like local date and time a spreadsheet sorts properly, or empty. */
export function csvDate(v: unknown): string {
  const d = toDate(v);
  if (!d) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** Saves [rows] under [head] as a .csv the browser downloads. */
export function downloadCsv(name: string, head: string[], rows: Cell[][]) {
  // The byte-order mark makes Excel read the file as UTF-8, so Bangla shows.
  const text = "﻿" + [head, ...rows].map((r) => r.map(cell).join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = `${name}-${csvDate(new Date()).slice(0, 10)}.csv`;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
