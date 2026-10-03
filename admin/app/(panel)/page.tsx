"use client";

import { collection, getCountFromServer, getDocs, limit, orderBy, query, Timestamp, where } from "firebase/firestore";
import Link from "next/link";
import { bucket, DailyBars, lastDays } from "@/components/bars";
import { Avatar, Badge, Card, Empty, ErrorNote, Loading, PageHeader, Stat } from "@/components/ui";
import { db } from "@/lib/firebase";
import { count, timeAgo, toDate } from "@/lib/format";
import { rows, type ReportDoc, type UserDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

async function load() {
  const now = Timestamp.now();
  const since = Timestamp.fromMillis(Date.now() - 14 * 86400000);
  const n = async (q: Parameters<typeof getCountFromServer>[0]) => (await getCountFromServer(q)).data().count;
  const [users, livePosts, openReports, communities, globalMessages, userDocs, postDocs, reportDocs] = await Promise.all([
    n(collection(db, "users")),
    n(query(collection(db, "posts"), where("expiresAt", ">", now))),
    n(query(collection(db, "reports"), where("status", "==", "open"))),
    n(collection(db, "communities")),
    n(collection(db, "rooms", "global", "messages")),
    getDocs(query(collection(db, "users"), limit(1000))),
    getDocs(query(collection(db, "posts"), where("postedAt", ">=", since), orderBy("postedAt", "desc"), limit(1000))),
    getDocs(query(collection(db, "reports"), where("status", "==", "open"), limit(5))),
  ]);
  const days = lastDays(14);
  const people = rows<UserDoc>(userDocs);
  const newest = [...people]
    .sort((a, b) => (toDate(b.createdAt)?.getTime() ?? 0) - (toDate(a.createdAt)?.getTime() ?? 0))
    .slice(0, 6);
  return {
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
