"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Icons } from "@/components/icons";
import { Avatar, Badge, Button, Card, cx, Empty, ErrorNote, ExportButton, inputClass, Loading, PageHeader, Table, td } from "@/components/ui";
import { csvDate, downloadCsv } from "@/lib/csv";
import { allUsers, communityNames } from "@/lib/data";
import { dateLabel, rText, toDate } from "@/lib/format";
import type { UserDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

const FILTERS = [
  { id: "all", label: "Everyone" },
  { id: "ranked", label: "Ranked" },
  { id: "unranked", label: "Not ranked yet" },
  { id: "banned", label: "Banned" },
] as const;

const SORTS = [
  { id: "newest", label: "Newest" },
  { id: "discipline", label: "Discipline" },
  { id: "trades", label: "Most trades" },
  { id: "name", label: "Name" },
] as const;

type Filter = (typeof FILTERS)[number]["id"];
type Sort = (typeof SORTS)[number]["id"];

function sorter(sort: Sort) {
  return (a: UserDoc, b: UserDoc) => {
    switch (sort) {
      case "discipline":
        return (b.disciplineScore ?? 0) - (a.disciplineScore ?? 0);
      case "trades":
        return (b.tradeCount ?? 0) - (a.tradeCount ?? 0);
      case "name":
        return (a.displayName ?? "").localeCompare(b.displayName ?? "");
      default:
        return (toDate(b.createdAt)?.getTime() ?? 0) - (toDate(a.createdAt)?.getTime() ?? 0);
    }
  };
}

export default function UsersPage() {
  const { data, error, loading } = useLoad(async () => {
    const [users, communities] = await Promise.all([allUsers(), communityNames()]);
    return { users, communities };
  });
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [sort, setSort] = useState<Sort>("newest");
  const [shown, setShown] = useState(50);

  const list = useMemo(() => {
    if (!data) return [];
    const needle = q.trim().replace(/^@/, "").toLowerCase();
    return data.users
      .filter((u) =>
        filter === "ranked" ? u.ranked : filter === "unranked" ? !u.ranked : filter === "banned" ? u.banned : true,
      )
      .filter((u) => !needle || u.username?.includes(needle) || u.displayName?.toLowerCase().includes(needle))
      .sort(sorter(sort));
  }, [data, q, filter, sort]);

  return (
    <>
      <PageHeader
        title="Users"
        subtitle={data ? `${data.users.length.toLocaleString("en-US")} accounts` : "Everyone with an account"}
        actions={
          <ExportButton
            disabled={!list.length}
            onClick={() =>
              downloadCsv(
                "users",
                ["username", "name", "joined", "community", "language", "ranked", "banned", "discipline", "trades", "win rate %", "total R", "journal streak"],
                list.map((u) => [
                  u.username, u.displayName, csvDate(u.createdAt), u.communityId ? (data?.communities.get(u.communityId)?.name ?? "") : "",
                  u.language ?? "bn", u.ranked ? "yes" : "no", u.banned ? "yes" : "no",
                  u.ranked ? Math.round(u.disciplineScore ?? 0) : "", u.tradeCount ?? 0, Math.round((u.winRate ?? 0) * 100),
                  (u.totalR ?? 0).toFixed(2), u.journalStreak ?? 0,
                ]),
              )
            }
          />
        }
      />
      <ErrorNote error={error} />
      <Card flush>
        <div className="flex flex-col gap-3 border-b border-line-soft p-4 lg:flex-row lg:items-center">
          <label className="relative flex-1">
            <span className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-faint"><Icons.search /></span>
            <input
              id="user-search"
              className={cx(inputClass, "pl-10")}
              placeholder="Search by name or @username"
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setShown(50);
              }}
            />
          </label>
          <div className="flex flex-wrap gap-1.5">
            {FILTERS.map((f) => (
              <button
                key={f.id}
                onClick={() => setFilter(f.id)}
                className={cx(
                  "h-9 rounded-lg px-3 text-[13px] font-medium",
                  filter === f.id ? "bg-primary text-white" : "bg-sunken text-muted hover:text-ink",
                )}
              >
                {f.label}
              </button>
            ))}
          </div>
          <select id="user-sort" className={cx(inputClass, "lg:w-44")} value={sort} onChange={(e) => setSort(e.target.value as Sort)}>
            {SORTS.map((s) => (
              <option key={s.id} value={s.id}>Sort: {s.label}</option>
            ))}
          </select>
        </div>
        {loading && !data ? (
          <Loading />
        ) : list.length === 0 ? (
          <Empty title="Nobody matches" hint="Try another name, or another filter." />
        ) : (
          <>
            <Table head={["User", "Community", "Discipline", "Trades", "Total R", "Joined", ""]}>
              {list.slice(0, shown).map((u) => {
                const c = u.communityId ? data?.communities.get(u.communityId) : undefined;
                return (
                  <tr key={u.id} className="hover:bg-sunken/50">
                    <td className={td}>
                      <Link href={`/users/view/?uid=${u.id}`} className="flex min-w-[200px] items-center gap-3">
                        <Avatar id={u.avatarId} />
                        <span className="min-w-0">
                          <span className="block truncate font-medium text-ink-strong">{u.displayName}</span>
                          <span className="block truncate text-xs text-muted">@{u.username}</span>
                        </span>
                      </Link>
                    </td>
                    <td className={cx(td, "max-w-[220px] truncate text-muted")}>{c?.name ?? "—"}</td>
                    <td className={cx(td, "tabular")}>{u.ranked ? Math.round(u.disciplineScore ?? 0) : "—"}</td>
                    <td className={cx(td, "tabular")}>{u.tradeCount ?? 0}</td>
                    <td className={cx(td, "tabular", (u.totalR ?? 0) < 0 ? "text-bad" : (u.totalR ?? 0) > 0 ? "text-good" : "")}>{rText(u.totalR ?? 0)}</td>
                    <td className={cx(td, "whitespace-nowrap text-muted")}>{dateLabel(u.createdAt)}</td>
                    <td className={cx(td, "text-right")}>
                      {u.banned ? <Badge tone="bad">Banned</Badge> : u.ranked ? <Badge tone="good">Ranked</Badge> : null}
                    </td>
                  </tr>
                );
              })}
            </Table>
            {list.length > shown && (
              <div className="border-t border-line-soft p-4 text-center">
                <Button onClick={() => setShown((n) => n + 50)}>Show more ({list.length - shown} left)</Button>
              </div>
            )}
          </>
        )}
      </Card>
    </>
  );
}
