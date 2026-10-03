import { dateLabel } from "@/lib/format";

/** Daily counts as bars, to scale, with the busiest day labelled. */
export function DailyBars({ days, label }: { days: { day: Date; n: number }[]; label: string }) {
  const max = Math.max(1, ...days.map((d) => d.n));
  const total = days.reduce((s, d) => s + d.n, 0);
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <div className="text-[13px] text-muted">{label}</div>
        <div className="tabular text-sm font-semibold text-ink-strong">{total.toLocaleString("en-US")}</div>
      </div>
      <div className="mt-4 flex h-32 items-end gap-1.5" role="img" aria-label={`${label}: ${total}`}>
        {days.map((d) => (
          <div key={d.day.toISOString()} className="group relative flex h-full flex-1 flex-col justify-end">
            <div
              className="min-h-[2px] rounded-t-[4px] bg-ink/80 transition-colors group-hover:bg-ink"
              style={{ height: `${(d.n / max) * 100}%` }}
            />
            <div className="pointer-events-none absolute -top-7 left-1/2 hidden -translate-x-1/2 rounded-md bg-ink-strong px-2 py-1 text-[11px] whitespace-nowrap text-white group-hover:block">
              {d.n} · {dateLabel(d.day).replace(/ \d{4}$/, "")}
            </div>
          </div>
        ))}
      </div>
      <div className="mt-2 flex justify-between text-[11px] text-faint">
        <span>{dateLabel(days[0]?.day).replace(/ \d{4}$/, "")}</span>
        <span>Today</span>
      </div>
    </div>
  );
}

/** The last [n] days, midnight to midnight, local time. */
export function lastDays(n: number, now = new Date()) {
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (n - 1));
  return Array.from({ length: n }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
}

export function bucket(dates: (Date | null)[], days: Date[]) {
  const counts = days.map((day) => ({ day, n: 0 }));
  const first = days[0].getTime();
  for (const d of dates) {
    if (!d) continue;
    const i = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() - first) / 86400000);
    if (i >= 0 && i < counts.length) counts[i].n++;
  }
  return counts;
}
