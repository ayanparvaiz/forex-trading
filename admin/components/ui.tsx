"use client";

import Link from "next/link";
import { pad2 } from "@/lib/format";

type Children = { children?: React.ReactNode };

export function cx(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "ghost" | "danger";
  size?: "sm" | "md";
  loading?: boolean;
};

export function Button({ variant = "secondary", size = "md", loading, className, children, disabled, ...rest }: ButtonProps) {
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={cx(
        "inline-flex items-center justify-center gap-2 rounded-lg font-medium whitespace-nowrap transition-colors disabled:cursor-not-allowed disabled:opacity-50",
        size === "sm" ? "h-8 px-3 text-[13px]" : "h-10 px-4 text-sm",
        variant === "primary" && "bg-primary text-white hover:bg-primary-hover",
        variant === "secondary" && "border border-line bg-surface text-ink hover:bg-sunken",
        variant === "ghost" && "text-muted hover:bg-sunken hover:text-ink",
        variant === "danger" && "border border-bad/25 bg-surface text-bad hover:bg-bad-soft",
        className,
      )}
    >
      {loading && <Spinner small />}
      {children}
    </button>
  );
}

export function Spinner({ small }: { small?: boolean }) {
  return (
    <span
      aria-hidden
      className={cx(
        "inline-block animate-spin rounded-full border-2 border-current border-r-transparent",
        small ? "size-3.5" : "size-5 text-faint",
      )}
    />
  );
}

export function Card({ title, actions, children, className, flush }: Children & {
  title?: React.ReactNode;
  actions?: React.ReactNode;
  className?: string;
  flush?: boolean;
}) {
  return (
    <section className={cx("min-w-0 rounded-[var(--radius-card)] border border-line bg-surface shadow-[var(--shadow-card)]", className)}>
      {(title || actions) && (
        <header className="flex flex-wrap items-center justify-between gap-3 border-b border-line-soft px-5 py-3.5">
          <h2 className="text-[15px] font-semibold text-ink-strong">{title}</h2>
          {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
        </header>
      )}
      <div className={flush ? "" : "p-5"}>{children}</div>
    </section>
  );
}

type Tone = "neutral" | "good" | "warn" | "bad" | "dark";

export function Badge({ tone = "neutral", children }: Children & { tone?: Tone }) {
  return (
    <span
      className={cx(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap",
        tone === "neutral" && "bg-sunken text-muted",
        tone === "good" && "bg-good-soft text-good",
        tone === "warn" && "bg-warn-soft text-warn",
        tone === "bad" && "bg-bad-soft text-bad",
        tone === "dark" && "bg-primary text-white",
      )}
    >
      {children}
    </span>
  );
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: React.ReactNode; actions?: React.ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        <h1 className="text-2xl font-semibold tracking-tight text-ink-strong text-balance">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-muted">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function Stat({ label, value, hint, href }: { label: string; value: React.ReactNode; hint?: React.ReactNode; href?: string }) {
  const body = (
    <>
      <div className="text-[13px] text-muted">{label}</div>
      <div className="tabular mt-1.5 text-[28px] leading-none font-semibold tracking-tight text-ink-strong">{value}</div>
      {hint && <div className="mt-2 text-xs text-muted">{hint}</div>}
    </>
  );
  const cls = "block min-w-0 rounded-[var(--radius-card)] border border-line bg-surface p-5 shadow-[var(--shadow-card)]";
  return href ? (
    <Link href={href} className={cx(cls, "transition-colors hover:border-faint")}>
      {body}
    </Link>
  ) : (
    <div className={cls}>{body}</div>
  );
}

export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="px-6 py-12 text-center">
      <div className="text-sm font-medium text-ink">{title}</div>
      {hint && <div className="mt-1 text-sm text-muted">{hint}</div>}
    </div>
  );
}

export function Loading({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="flex items-center justify-center gap-3 px-6 py-12 text-sm text-muted">
      <Spinner /> {label}
    </div>
  );
}

export function ErrorNote({ error }: { error: unknown }) {
  if (!error) return null;
  return (
    <div className="rounded-lg border border-bad/20 bg-bad-soft px-4 py-3 text-sm text-bad">
      {error instanceof Error ? error.message : String(error)}
    </div>
  );
}

export const inputClass =
  "h-10 w-full min-w-0 rounded-lg border border-line bg-surface px-3 text-sm text-ink placeholder:text-faint focus:border-ink focus:outline-none";

export function Avatar({ id, size = 36 }: { id?: number | null; size?: number }) {
  const n = typeof id === "number" && id >= 1 && id <= 24 ? id : 1;
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={`/avatars/${pad2(n)}.svg`} alt="" width={size} height={size} className="shrink-0 rounded-full bg-sunken" />
  );
}

export function CommunityPicture({ id, name, size = 36 }: { id?: number | null; name?: string; size?: number }) {
  if (typeof id === "number" && id >= 1 && id <= 28) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img src={`/community-avatars/${pad2(id)}.svg`} alt="" width={size} height={size} className="shrink-0 rounded-[10px] bg-sunken" />
    );
  }
  return (
    <span
      style={{ width: size, height: size }}
      className="grid shrink-0 place-items-center rounded-[10px] bg-sunken text-sm font-semibold text-muted"
    >
      {(name ?? "?").slice(0, 1).toUpperCase()}
    </span>
  );
}

/** A table that scrolls sideways on its own when the screen is narrow. */
export function Table({ head, children }: Children & { head: React.ReactNode[] }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-line-soft text-xs font-medium tracking-wide text-muted uppercase">
            {head.map((h, i) => (
              <th key={i} className="px-5 py-3 font-medium whitespace-nowrap">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-line-soft">{children}</tbody>
      </table>
    </div>
  );
}

export const td = "px-5 py-3 align-middle";

/** "Export CSV": the rows on screen, as a spreadsheet. */
export function ExportButton({ onClick, disabled }: { onClick: () => void; disabled?: boolean }) {
  return (
    <Button size="sm" onClick={onClick} disabled={disabled} title="Download what is shown as a spreadsheet">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d="M12 4v11M7.5 10.5L12 15l4.5-4.5M5 19h14" />
      </svg>
      Export CSV
    </Button>
  );
}

/** In place of a page or a part of one that is for admins only. */
export function AdminsOnly() {
  return (
    <Card>
      <Empty title="For admins only" hint="Moderators look after posts, comments, messages and reports. An admin can do this." />
    </Card>
  );
}
