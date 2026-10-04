"use client";

import { useState } from "react";
import { lastDays } from "./bars";
import { LineChart, type Point } from "./line-chart";
import { Card, cx } from "./ui";
import { dateLabel, toDate } from "@/lib/format";

export type Snapshot = { date: string; accounts?: number; trades?: number; active1d?: number; active7d?: number };

const METRICS = [
  { id: "accounts", label: "Accounts" },
  { id: "active", label: "Daily active" },
  { id: "trades", label: "Closed trades" },
] as const;
type Metric = (typeof METRICS)[number]["id"];

const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

/**
 * How the app grows, day by day. Accounts from when each was made — so the
 * whole history; who used it and trades from the worker's morning count
 * (worker/src/snapshot.js), from the day that began.
 */
export function Growth({ joined, snapshots }: { joined: (Date | null)[]; snapshots: Snapshot[] }) {
  const [metric, setMetric] = useState<Metric>("accounts");
  const [range, setRange] = useState<30 | 90>(30);
  const days = lastDays(range);
  const byDate = new Map(snapshots.map((s) => [s.date, s]));
  const made = joined.filter((d): d is Date => d != null).map((d) => d.getTime());

  const points: Point[] = days.map((day) => {
    if (metric === "accounts") {
      const end = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1).getTime();
      return { day, value: made.filter((t) => t < end).length };
    }
    const s = byDate.get(iso(day));
    const v = metric === "active" ? s?.active1d : s?.trades;
    return { day, value: typeof v === "number" ? v : null };
  });
  const first = snapshots.map((s) => s.date).sort()[0];
  const label = METRICS.find((m) => m.id === metric)!.label;

  const chip = (on: boolean) =>
    cx("h-8 rounded-lg px-3 text-[13px] font-medium", on ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink");
  return (
    <Card
      title="Growth"
      actions={
        <div className="flex flex-wrap gap-1.5">
          {METRICS.map((m) => (
            <button key={m.id} type="button" className={chip(metric === m.id)} onClick={() => setMetric(m.id)}>{m.label}</button>
          ))}
          <span className="mx-1 w-px self-stretch bg-line" aria-hidden />
          {([30, 90] as const).map((r) => (
            <button key={r} type="button" className={chip(range === r)} onClick={() => setRange(r)}>{r} days</button>
          ))}
        </div>
      }
    >
      <LineChart points={points} label={label} />
      {metric !== "accounts" && (
        <p className="mt-2 text-xs text-faint">
          {metric === "active" ? "People who opened the app in the 24 hours before each morning's count" : "All trades ever closed, counted each morning"}
          {first ? ` — counted since ${dateLabel(toDate(`${first}T12:00:00`))}.` : " — the first count is tomorrow morning."}
        </p>
      )}
    </Card>
  );
}
