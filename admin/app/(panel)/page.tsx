"use client";

import { collection, getCountFromServer, getDocs, limit, orderBy, query, Timestamp, where } from "firebase/firestore";
import Link from "next/link";
import { bucket, DailyBars, lastDays } from "@/components/bars";
import { Growth, type Snapshot } from "@/components/growth";
import { Avatar, Badge, Card, Empty, ErrorNote, Loading, PageHeader, Stat } from "@/components/ui";
import { db } from "@/lib/firebase";
import { count, timeAgo, toDate } from "@/lib/format";
import { rows, type ReportDoc, type UserDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

async function load() {
  const now = Timestamp.now();
  const since = Timestamp.fromMillis(Date.now() - 14 * 86400000);
  const n = async (q: Parameters<typeof getCountFromServer>[0]) => (await getCountFromServer(q)).data().count;
  // Who used the app lately: the app stamps presence/{uid} once a minute
  // while it is open (app/lib/data/chat_inbox.dart).
  const activeSince = (ms: number) =>
    n(query(collection(db, "presence"), where("lastActiveAt", ">=", Timestamp.fromMillis(Date.now() - ms))));
  const [online, today, week, month] = await Promise.all([
    activeSince(5 * 60_000),
    activeSince(86_400_000),
    activeSince(7 * 86_400_000),
    activeSince(30 * 86_400_000),
  ]);
  const ninetyDaysAgo = new Date(Date.now() - 91 * 86400000).toISOString().slice(0, 10);
  const [users, livePosts, openReports, communities, globalMessages, userDocs, postDocs, reportDocs, stats] = await Promise.all([
    n(collection(db, "users")),
    n(query(collection(db, "posts"), where("expiresAt", ">", now))),
    n(query(collection(db, "reports"), where("status", "==", "open"))),
    n(collection(db, "communities")),
    n(collection(db, "rooms", "global", "messages")),
    getDocs(query(collection(db, "users"), limit(1000))),
    getDocs(query(collection(db, "posts"), where("postedAt", ">=", since), orderBy("postedAt", "desc"), limit(1000))),
    getDocs(query(collection(db, "reports"), where("status", "==", "open"), limit(5))),
    getDocs(query(collection(db, "stats"), where("date", ">=", ninetyDaysAgo), limit(120))),
  ]);
  const days = lastDays(14);
  const people = rows<UserDoc>(userDocs);
  const newest = [...people]
    .sort((a, b) => (toDate(b.createdAt)?.getTime() ?? 0) - (toDate(a.createdAt)?.getTime() ?? 0))
    .slice(0, 6);
  return {
    active: { online, today, week, month },
    users,
    ranked: people.filter((p) => p.ranked).length,
    banned: people.filter((p) => p.banned).length,
    livePosts,
    openReports,
    communities,
    globalMessages,
    signups: bucket(people.map((p) => toDate(p.createdAt)), days),
    posts: bucket(postDocs.docs.map((d) => toDate(d.data().postedAt)), days),
    newest,
    reports: rows<ReportDoc>(reportDocs),
    joined: people.map((p) => toDate(p.createdAt)),
    snapshots: stats.docs.map((d) => d.data() as Snapshot),
  };
}

export default function Dashboard() {
  const { data, error, loading } = useLoad(load);
  return (
    <>
      <PageHeader title="Dashboard" subtitle="Forex Social at a glance." />
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : data ? (
        <div className="flex flex-col gap-6">
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
            <Stat label="Accounts" value={count(data.users)} hint={`${data.ranked} ranked · ${data.banned} banned`} href="/users/" />
            <Stat label="Posts on the feed" value={count(data.livePosts)} hint="Up for 7 days each" href="/feed/" />
            <Stat label="Open reports" value={count(data.openReports)} hint={data.openReports ? "Waiting for you" : "All clear"} href="/reports/" />
            <Stat label="Communities" value={count(data.communities)} href="/communities/" />
            <Stat label="Global chat messages" value={count(data.globalMessages)} href="/rooms/" />
          </div>

          <Card title="People using the app" actions={<span className="text-xs text-muted">Counted while the app is open; not those who hide when they were last active</span>}>
            <div className="grid grid-cols-2 gap-x-4 gap-y-5 sm:grid-cols-4">
              {[
                ["Right now", data.active.online],
                ["Last 24 hours", data.active.today],
                ["Last 7 days", data.active.week],
                ["Last 30 days", data.active.month],
              ].map(([label, value]) => (
                <div key={label as string} className="min-w-0">
                  <div className="text-xs text-muted">{label}</div>
                  <div className="tabular mt-1 flex items-center gap-2 text-2xl font-semibold text-ink-strong">
                    {label === "Right now" && (value as number) > 0 && <span className="size-2 rounded-full bg-good" aria-hidden />}
                    {count(value)}
                  </div>
                  <div className="text-xs text-faint">{data.users ? Math.round(((value as number) / data.users) * 100) : 0}% of accounts</div>
                </div>
              ))}
            </div>
          </Card>

          <Growth joined={data.joined} snapshots={data.snapshots} />

          <div className="grid gap-6 lg:grid-cols-2">
            <Card title="New accounts"><DailyBars days={data.signups} label="Last 14 days" /></Card>
            <Card title="Posts"><DailyBars days={data.posts} label="Last 14 days" /></Card>
          </div>

          <div className="grid gap-6 lg:grid-cols-2">
            <Card title="Newest accounts" actions={<Link className="text-sm text-muted hover:text-ink" href="/users/">All users →</Link>} flush>
              <ul className="divide-y divide-line-soft">
                {data.newest.map((u) => (
                  <li key={u.id}>
                    <Link href={`/users/view/?uid=${u.id}`} className="flex items-center gap-3 px-5 py-3 hover:bg-sunken/60">
                      <Avatar id={u.avatarId} />
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-medium text-ink-strong">{u.displayName}</div>
                        <div className="truncate text-xs text-muted">@{u.username}</div>
                      </div>
                      <span className="text-xs text-muted">{timeAgo(u.createdAt)}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            </Card>
            <Card title="Open reports" actions={<Link className="text-sm text-muted hover:text-ink" href="/reports/">All reports →</Link>} flush>
              {data.reports.length === 0 ? (
                <Empty title="Nothing reported" hint="When someone reports a post, message or person, it shows here." />
              ) : (
                <ul className="divide-y divide-line-soft">
                  {data.reports.map((r) => (
                    <li key={r.id}>
                      <Link href="/reports/" className="flex items-center gap-3 px-5 py-3 hover:bg-sunken/60">
                        <Badge tone="warn">{r.reason}</Badge>
                        <div className="min-w-0 flex-1 truncate text-sm text-ink">
                          {r.kind} by @{r.targetUsername}
                        </div>
                        <span className="text-xs text-muted">{timeAgo(r.createdAt)}</span>
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          </div>
        </div>
      ) : null}
    </>
  );
}
