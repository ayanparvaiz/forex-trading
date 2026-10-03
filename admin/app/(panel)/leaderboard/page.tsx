"use client";

import { collection, getDocs, limit, query } from "firebase/firestore";
import Link from "next/link";
import { useState } from "react";
import { Avatar, Badge, Card, CommunityPicture, Empty, ErrorNote, Loading, PageHeader, Table, cx, td } from "@/components/ui";
import { allCommunities, allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { rText } from "@/lib/format";
import { rows, type CommunityDoc, type UserDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

const DAY_MS = 86_400_000;
const DHAKA_OFFSET_MS = 6 * 60 * 60 * 1000;
const TOP = 50;

/** The ISO week [ms] falls in, in Dhaka — as worker/src/weekly.js has it. */
function weekId(ms: number) {
  const day = new Date(Math.floor((ms + DHAKA_OFFSET_MS) / DAY_MS) * DAY_MS);
  const weekday = day.getUTCDay() || 7;
  const thursday = new Date(day.getTime() + (4 - weekday) * DAY_MS);
  const year = thursday.getUTCFullYear();
  const week = Math.floor((thursday.getTime() - Date.UTC(year, 0, 1)) / DAY_MS / 7) + 1;
  return `${year}-W${String(week).padStart(2, "0")}`;
}

type Champion = { id: string; month: string; communityId: string; name: string; points: number };

async function load() {
  const [users, communities, champions] = await Promise.all([
    allUsers(),
    allCommunities(),
    getDocs(query(collection(db, "champions"), limit(120))),
  ]);
  const week = weekId(Date.now());
  // As the app orders them: by discipline, then trades.
  const board = users
    .filter((u) => u.ranked)
    .sort((a, b) => (b.disciplineScore ?? 0) - (a.disciplineScore ?? 0) || (b.tradeCount ?? 0) - (a.tradeCount ?? 0));
  const weekly = users
    .filter((u) => u.weekBoard === week)
    .sort((a, b) => (b.weekScore ?? 0) - (a.weekScore ?? 0) || (b.weekTrades ?? 0) - (a.weekTrades ?? 0));
  // A member at #1 of the top fifty is worth 50 to their community, #50 worth 1.
  const points = new Map<string, number>();
  board.slice(0, TOP).forEach((u, i) => {
    if (u.communityId) points.set(u.communityId, (points.get(u.communityId) ?? 0) + (TOP - i));
  });
  const ranked = communities
    .map((c) => ({ ...c, points: points.get(c.id) ?? 0 }))
    .sort((a, b) => b.points - a.points || (b.memberCount ?? 0) - (a.memberCount ?? 0) || a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
  return {
    week,
    board,
    weekly,
    ranked,
    champions: rows<Champion>(champions).sort((a, b) => b.month.localeCompare(a.month)),
    names: new Map(communities.map((c) => [c.id, c])),
  };
}

const TABS = [
  { id: "all", label: "All time" },
  { id: "week", label: "This week" },
  { id: "communities", label: "Communities" },
] as const;
type Tab = (typeof TABS)[number]["id"];

const monthLabel = (m: string) =>
  new Date(`${m}-01T00:00:00Z`).toLocaleDateString("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });

function Place({ i }: { i: number }) {
  return <span className={cx("tabular", i < 3 ? "font-semibold text-ink-strong" : "text-muted")}>{i + 1}</span>;
}

function Trader({ u }: { u: UserDoc }) {
  return (
    <Link href={`/users/view/?uid=${u.id}`} className="flex min-w-[180px] items-center gap-3">
      <Avatar id={u.avatarId} size={32} />
      <span className="min-w-0">
        <span className="flex items-center gap-2">
          <span className="truncate font-medium text-ink-strong">{u.displayName}</span>
          {u.banned && <Badge tone="bad">Banned</Badge>}
        </span>
        <span className="block truncate text-xs text-muted">@{u.username}</span>
      </span>
    </Link>
  );
}

const rClass = (r: number) => cx(td, "tabular", r < 0 ? "text-bad" : r > 0 ? "text-good" : "");

export default function LeaderboardPage() {
  const [tab, setTab] = useState<Tab>("all");
  const { data, error, loading } = useLoad(load);
  const community = (id?: string) => (id ? (data?.names.get(id)?.name ?? "—") : "—");

  return (
    <>
      <PageHeader title="Leaderboard" subtitle="The rankings as the app shows them. Scores come from each trader's journal and can't be edited here." />
      <div className="mb-4 flex gap-1.5 overflow-x-auto">
        {TABS.map((t) => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={cx(
              "h-9 shrink-0 rounded-lg px-3.5 text-[13px] font-medium",
              tab === t.id ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink",
            )}>
            {t.label}
          </button>
        ))}
      </div>
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : !data ? null : tab === "all" ? (
        <Card title={`Ranked traders · ${data.board.length}`} flush>
          {data.board.length === 0 ? (
            <Empty title="Nobody ranked yet" hint="Traders are ranked once they have closed enough trades." />
          ) : (
            <Table head={["#", "Trader", "Community", "Discipline", "Trades", "Win rate", "Total R"]}>
              {data.board.map((u, i) => (
                <tr key={u.id}>
                  <td className={td}><Place i={i} /></td>
                  <td className={td}><Trader u={u} /></td>
                  <td className={cx(td, "max-w-[220px] truncate text-muted")}>{community(u.communityId)}</td>
                  <td className={cx(td, "tabular font-medium text-ink-strong")}>{Math.round(u.disciplineScore ?? 0)}</td>
                  <td className={cx(td, "tabular")}>{u.tradeCount ?? 0}</td>
                  <td className={cx(td, "tabular")}>{Math.round((u.winRate ?? 0) * 100)}%</td>
                  <td className={rClass(u.totalR ?? 0)}>{rText(u.totalR ?? 0)}</td>
                </tr>
              ))}
            </Table>
          )}
        </Card>
      ) : tab === "week" ? (
        <Card title={`Week ${data.week.split("-W")[1]} · ${data.weekly.length} on the board`} flush>
          {data.weekly.length === 0 ? (
            <Empty title="Nobody on this week's board yet" hint="A trader joins it with enough closed trades this week." />
          ) : (
            <Table head={["#", "Trader", "Community", "Week score", "Trades", "R this week"]}>
              {data.weekly.map((u, i) => (
                <tr key={u.id}>
                  <td className={td}><Place i={i} /></td>
                  <td className={td}><Trader u={u} /></td>
                  <td className={cx(td, "max-w-[220px] truncate text-muted")}>{community(u.communityId)}</td>
                  <td className={cx(td, "tabular font-medium text-ink-strong")}>{Math.round(u.weekScore ?? 0)}</td>
                  <td className={cx(td, "tabular")}>{u.weekTrades ?? 0}</td>
                  <td className={rClass(u.weekR ?? 0)}>{rText(u.weekR ?? 0)}</td>
                </tr>
              ))}
            </Table>
          )}
        </Card>
      ) : (
        <div className="grid gap-6 lg:grid-cols-3">
          <div className="min-w-0 lg:col-span-2">
            <Card title="Community ranking" actions={<span className="text-xs text-muted">#1 of the top {TOP} is worth {TOP} points, #{TOP} worth 1</span>} flush>
              <Table head={["#", "Community", "Points", "Members", "Titles"]}>
                {data.ranked.map((c: CommunityDoc & { points: number }, i) => (
                  <tr key={c.id}>
                    <td className={td}><Place i={i} /></td>
                    <td className={td}>
                      <Link href={`/communities/view/?id=${c.id}`} className="flex min-w-[200px] items-center gap-3">
                        <CommunityPicture id={c.avatarId} name={c.name} size={32} />
                        <span className="line-clamp-2 font-medium text-ink-strong">{c.name}</span>
                      </Link>
                    </td>
                    <td className={cx(td, "tabular font-medium text-ink-strong")}>{c.points}</td>
                    <td className={cx(td, "tabular")}>{c.memberCount ?? 0}</td>
                    <td className={td}>{(c.titles ?? []).length ? <Badge tone="dark">🏆 ×{c.titles?.length}</Badge> : <span className="text-faint">—</span>}</td>
                  </tr>
                ))}
              </Table>
            </Card>
          </div>
          <Card title="Champions by month" className="h-fit" flush>
            {data.champions.length === 0 ? (
              <Empty title="No champion yet" hint="The top community is crowned on the first morning of each month." />
            ) : (
              <ul className="divide-y divide-line-soft">
                {data.champions.map((ch) => (
                  <li key={ch.id} className="flex items-center gap-3 px-5 py-3">
                    <span className="text-lg">🏆</span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-sm font-medium text-ink-strong">{monthLabel(ch.month)}</span>
                      <span className="block truncate text-xs text-muted">
                        {ch.communityId ? `${data.names.get(ch.communityId)?.name ?? ch.name} · ${ch.points} points` : "Nobody had points"}
                      </span>
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      )}
    </>
  );
}
