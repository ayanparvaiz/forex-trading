"use client";

import { useEffect, useId, useRef, useState } from "react";
import { dateLabel } from "@/lib/format";

export type Point = { day: Date; value: number | null };

/** Round tick steps: 1, 2, 5 × a power of ten, about four, never a fraction — these are counts. */
function ticks(max: number): number[] {
  if (max <= 0) return [0, 1];
  const rough = max / 4;
  const power = 10 ** Math.floor(Math.log10(rough));
  const step = Math.max(1, [1, 2, 5, 10].map((m) => m * power).find((s) => s >= rough) ?? power * 10);
  const top = Math.ceil(max / step) * step;
  return Array.from({ length: Math.round(top / step) + 1 }, (_, i) => i * step);
}

const short = (d: Date) => dateLabel(d).replace(/ \d{4}$/, "");
const num = (n: number) => n.toLocaleString("en-US");

/**
 * One series over days: a 2px line with a faint wash under it, the latest
 * value at its end, a hairline grid on round numbers. Hover or arrow keys
 * move a crosshair that reads the day out; days with nothing recorded are
 * a gap, not a zero.
 */
export function LineChart({ points, label }: { points: Point[]; label: string }) {
  // Drawn at the width it is shown, so text stays its real size on a phone.
  const frame = useRef<HTMLDivElement>(null);
  const [W, setW] = useState(720);
  useEffect(() => {
    const el = frame.current;
    if (!el) return;
    const seen = new ResizeObserver(([entry]) => setW(Math.max(280, Math.round(entry.contentRect.width))));
    seen.observe(el);
    return () => seen.disconnect();
  }, []);
  const H = W < 500 ? 180 : 220;
  const pad = { top: 16, right: 44, bottom: 28, left: 40 };
  const [at, setAt] = useState<number | null>(null);
  const box = useRef<SVGSVGElement>(null);
  const id = useId();

  const known = points.map((p) => p.value).filter((v): v is number => v != null);
  const grid = ticks(Math.max(1, ...known));
  const top = grid[grid.length - 1];
  const x = (i: number) => pad.left + (points.length <= 1 ? 0 : (i / (points.length - 1)) * (W - pad.left - pad.right));
  const y = (v: number) => pad.top + (1 - v / top) * (H - pad.top - pad.bottom);

  // Runs of recorded days, each drawn as its own line.
  const runs: { i: number; v: number }[][] = [];
  points.forEach((p, i) => {
    if (p.value == null) return;
    const last = runs[runs.length - 1];
    if (last && last[last.length - 1].i === i - 1) last.push({ i, v: p.value });
    else runs.push([{ i, v: p.value }]);
  });
  const lastKnown = [...points.keys()].reverse().find((i) => points[i].value != null);

  const move = (clientX: number) => {
    const r = box.current?.getBoundingClientRect();
    if (!r) return;
    const px = ((clientX - r.left) / r.width) * W;
    const i = Math.round(((px - pad.left) / (W - pad.left - pad.right)) * (points.length - 1));
    setAt(Math.max(0, Math.min(points.length - 1, i)));
  };
  const key = (e: React.KeyboardEvent) => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
    e.preventDefault();
    const from = at ?? lastKnown ?? points.length - 1;
    setAt(Math.max(0, Math.min(points.length - 1, from + (e.key === "ArrowLeft" ? -1 : 1))));
  };

  const hovered = at != null ? points[at] : null;
  const tipLeft = at != null ? (x(at) / W) * 100 : 0;

  return (
    <div>
      <div ref={frame} className="relative">
        <svg
          ref={box}
          viewBox={`0 0 ${W} ${H}`}
          className="block h-auto w-full touch-none outline-none focus-visible:ring-2 focus-visible:ring-ink/30"
          role="img"
          aria-labelledby={`${id}-t`}
          tabIndex={0}
          onPointerMove={(e) => move(e.clientX)}
          onPointerDown={(e) => move(e.clientX)}
          onPointerLeave={() => setAt(null)}
          onKeyDown={key}
          onBlur={() => setAt(null)}
        >
          <title id={`${id}-t`}>{`${label}${lastKnown != null ? `, latest ${num(points[lastKnown].value!)}` : ""}`}</title>
          {grid.map((t) => (
            <g key={t}>
              <line x1={pad.left} x2={W - pad.right} y1={y(t)} y2={y(t)} stroke="var(--color-line)" strokeWidth={1} />
              <text x={pad.left - 8} y={y(t)} textAnchor="end" dominantBaseline="middle" className="fill-faint text-[11px] tabular">
                {num(t)}
              </text>
            </g>
          ))}
          {[0, Math.floor((points.length - 1) / 2), points.length - 1].map((i, k) => (
            <text key={k} x={x(i)} y={H - 8} textAnchor={k === 0 ? "start" : k === 2 ? "end" : "middle"} className="fill-faint text-[11px]">
              {k === 2 ? "Today" : short(points[i].day)}
            </text>
          ))}
          {runs.map((run, k) => (
            <g key={k}>
              {run.length > 1 && (
                <path
                  d={`M${x(run[0].i)},${y(0)} ${run.map((p) => `L${x(p.i)},${y(p.v)}`).join(" ")} L${x(run[run.length - 1].i)},${y(0)} Z`}
                  fill="var(--color-ink)"
                  opacity={0.08}
                />
              )}
              <path
                d={run.map((p, j) => `${j ? "L" : "M"}${x(p.i)},${y(p.v)}`).join(" ")}
                fill="none"
                stroke="var(--color-ink)"
                strokeWidth={2}
                strokeLinejoin="round"
                strokeLinecap="round"
              />
            </g>
          ))}
          {lastKnown != null && (
            <g>
              <circle cx={x(lastKnown)} cy={y(points[lastKnown].value!)} r={6} fill="var(--color-surface)" />
              <circle cx={x(lastKnown)} cy={y(points[lastKnown].value!)} r={4} fill="var(--color-ink)" />
              <text x={x(lastKnown) + 10} y={y(points[lastKnown].value!)} dominantBaseline="middle" className="fill-ink-strong text-[12px] font-semibold tabular">
                {num(points[lastKnown].value!)}
              </text>
            </g>
          )}
          {at != null && (
            <g pointerEvents="none">
              <line x1={x(at)} x2={x(at)} y1={pad.top} y2={H - pad.bottom} stroke="var(--color-faint)" strokeWidth={1} />
              {hovered?.value != null && (
                <>
                  <circle cx={x(at)} cy={y(hovered.value)} r={6} fill="var(--color-surface)" />
                  <circle cx={x(at)} cy={y(hovered.value)} r={4} fill="var(--color-ink)" />
                </>
              )}
            </g>
          )}
        </svg>
        {hovered && (
          <div
            className="pointer-events-none absolute top-0 z-10 rounded-lg bg-ink-strong px-2.5 py-1.5 whitespace-nowrap text-white shadow-[var(--shadow-pop)]"
            style={{ left: `${tipLeft}%`, transform: `translateX(${tipLeft > 70 ? "-105%" : "8px"})` }}
          >
            <div className="tabular text-sm font-semibold">{hovered.value != null ? num(hovered.value) : "Not counted"}</div>
            <div className="text-[11px] text-white/70">{dateLabel(hovered.day)}</div>
          </div>
        )}
      </div>
      <details className="mt-2 text-xs text-muted">
        <summary className="cursor-pointer select-none hover:text-ink">Show as a table</summary>
        <div className="mt-2 max-h-56 overflow-y-auto rounded-lg border border-line-soft">
          <table className="w-full text-left text-[13px]">
            <thead className="sticky top-0 bg-sunken text-muted">
              <tr><th className="px-3 py-1.5 font-medium">Day</th><th className="px-3 py-1.5 text-right font-medium">{label}</th></tr>
            </thead>
            <tbody>
              {[...points].reverse().map((p) => (
                <tr key={p.day.toISOString()} className="border-t border-line-soft">
                  <td className="px-3 py-1.5 text-ink">{dateLabel(p.day)}</td>
                  <td className="tabular px-3 py-1.5 text-right text-ink">{p.value != null ? num(p.value) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </div>
  );
}
