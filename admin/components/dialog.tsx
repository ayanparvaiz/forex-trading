"use client";

import { useEffect, useId } from "react";

/** A modal with its own form inside: Esc or a click outside closes it. */
export function Dialog({
  title,
  children,
  footer,
  onClose,
  wide,
}: {
  title: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  onClose: () => void;
  wide?: boolean;
}) {
  const id = useId();
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="fixed inset-0 z-50 grid place-items-center overflow-y-auto bg-ink-strong/30 p-4" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={id}
        className={`w-full ${wide ? "max-w-xl" : "max-w-md"} rounded-2xl border border-line bg-surface p-6 shadow-[var(--shadow-pop)]`}
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id={id} className="text-lg font-semibold text-ink-strong">{title}</h2>
        <div className="mt-3 text-sm leading-relaxed text-muted">{children}</div>
        {footer && <div className="mt-6 flex flex-wrap justify-end gap-2">{footer}</div>}
      </div>
    </div>
  );
}

/** A label over a field, with an optional count on the right. */
export function Field({ label, count, max, children }: { label: string; count?: number; max?: number; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="flex justify-between text-xs font-medium text-muted">
        {label}
        {max != null && <span className={`tabular ${(count ?? 0) > max ? "text-bad" : "text-faint"}`}>{count ?? 0}/{max}</span>}
      </span>
      {children}
    </label>
  );
}
