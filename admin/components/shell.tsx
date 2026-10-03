"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { useSession } from "@/lib/session";
import { Icons } from "./icons";
import { cx } from "./ui";

const NAV: { group?: string; items: { href: string; label: string; icon: () => React.ReactElement }[] }[] = [
  { items: [{ href: "/", label: "Dashboard", icon: Icons.dashboard }] },
  {
    group: "Moderation",
    items: [
      { href: "/users/", label: "Users", icon: Icons.users },
      { href: "/reports/", label: "Reports", icon: Icons.flag },
      { href: "/feed/", label: "Feed", icon: Icons.feed },
      { href: "/rooms/", label: "Chat rooms", icon: Icons.chat },
    ],
  },
  {
    group: "Community",
    items: [
      { href: "/communities/", label: "Communities", icon: Icons.community },
      { href: "/leaderboard/", label: "Leaderboard", icon: Icons.trophy },
    ],
  },
  {
    group: "App",
    items: [{ href: "/announcements/", label: "Announcements", icon: Icons.megaphone }],
  },
  {
    group: "Admin",
    items: [{ href: "/activity/", label: "Activity", icon: Icons.history }],
  },
];

function active(path: string, href: string) {
  return href === "/" ? path === "/" : path.startsWith(href);
}

function Mark() {
  return (
    <Link href="/" className="flex items-center gap-2.5">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/icon.png" alt="" width={30} height={30} className="rounded-[8px]" />
      <span className="leading-tight">
        <span className="block text-[15px] font-semibold text-ink-strong">Forex Social</span>
        <span className="block text-[11px] font-medium tracking-[0.08em] text-muted uppercase">Admin</span>
      </span>
    </Link>
  );
}

function Nav({ onPick }: { onPick?: () => void }) {
  const path = usePathname();
  return (
    <nav className="flex flex-col gap-4">
      {NAV.map(({ group, items }, i) => (
        <div key={group ?? i} className="flex flex-col gap-0.5">
          {group && <div className="px-3 pb-1 text-[11px] font-medium tracking-[0.08em] text-faint uppercase">{group}</div>}
          {items.map(({ href, label, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              onClick={onPick}
              className={cx(
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                active(path, href) ? "bg-sunken text-ink-strong" : "text-muted hover:bg-sunken/70 hover:text-ink",
              )}
            >
              <Icon />
              {label}
            </Link>
          ))}
        </div>
      ))}
    </nav>
  );
}

function Account() {
  const { user, signOut } = useSession();
  const name = user?.email?.split("@")[0] ?? "";
  return (
    <div className="flex items-center justify-between gap-2 border-t border-line-soft pt-4">
      <div className="min-w-0">
        <div className="truncate text-sm font-medium text-ink">@{name}</div>
        <div className="text-xs text-muted">Admin</div>
      </div>
      <button onClick={signOut} className="rounded-lg p-2 text-muted hover:bg-sunken hover:text-ink" title="Sign out" aria-label="Sign out">
        <Icons.out />
      </button>
    </div>
  );
}

/** The sidebar on wide screens; a top bar and a drawer on a phone. */
export function Shell({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="min-h-dvh lg:pl-64">
      <aside className="fixed inset-y-0 left-0 hidden w-64 flex-col gap-6 border-r border-line bg-surface px-4 py-5 lg:flex">
        <Mark />
        <div className="flex-1 overflow-y-auto"><Nav /></div>
        <Account />
      </aside>

      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-line bg-surface/95 px-4 py-3 backdrop-blur lg:hidden">
        <Mark />
        <button onClick={() => setOpen(true)} className="rounded-lg p-2 text-ink hover:bg-sunken" aria-label="Open menu">
          <Icons.menu />
        </button>
      </header>
      {open && (
        <div className="fixed inset-0 z-40 bg-ink-strong/30 lg:hidden" onClick={() => setOpen(false)}>
          <div className="flex h-full w-72 max-w-[85vw] flex-col gap-6 bg-surface px-4 py-5" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <Mark />
              <button onClick={() => setOpen(false)} className="rounded-lg p-2 text-muted hover:bg-sunken" aria-label="Close menu">
                <Icons.close />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto"><Nav onPick={() => setOpen(false)} /></div>
            <Account />
          </div>
        </div>
      )}

      <main className="mx-auto w-full max-w-7xl px-4 py-6 sm:px-6 lg:px-10 lg:py-9">{children}</main>
    </div>
  );
}
