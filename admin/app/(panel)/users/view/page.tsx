"use client";

import { collection, getDoc, getDocs, doc, limit, query, where } from "firebase/firestore";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { ActivityList } from "@/components/activity";
import { useAction } from "@/components/feedback";
import { Avatar, Badge, Button, Card, CommunityPicture, Empty, ErrorNote, Loading, PageHeader, Stat } from "@/components/ui";
import { activityAbout } from "@/lib/activity";
import { adminCall } from "@/lib/admin-api";
import { db } from "@/lib/firebase";
import { dateLabel, dateTime, rText, timeAgo, toDate } from "@/lib/format";
import { ACHIEVEMENTS, KINDS, REPORT_REASONS } from "@/lib/labels";
import { rows, type CommunityDoc, type PostDoc, type ReportDoc, type UserDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";
import { BanDialog, PasswordDialog, ResetDialog, WarnDialog } from "./people-dialogs";

async function load(uid: string) {
  const snap = await getDoc(doc(db, "users", uid));
  if (!snap.exists()) return null;
  const user = { id: snap.id, ...snap.data() } as UserDoc;
  const [posts, reports, community, history] = await Promise.all([
    getDocs(query(collection(db, "posts"), where("authorUid", "==", uid), limit(50))),
    getDocs(query(collection(db, "reports"), where("targetUid", "==", uid), limit(50))),
    user.communityId ? getDoc(doc(db, "communities", user.communityId)) : Promise.resolve(null),
    activityAbout(uid),
  ]);
  const by = (v: unknown) => toDate(v)?.getTime() ?? 0;
  return {
    user,
    posts: rows<PostDoc>(posts).sort((a, b) => by(b.postedAt) - by(a.postedAt)),
    reports: rows<ReportDoc>(reports).sort((a, b) => by(b.createdAt) - by(a.createdAt)),
    community: community?.exists() ? ({ id: community.id, ...community.data() } as CommunityDoc) : null,
    history,
  };
}

function UserView() {
  const uid = useSearchParams().get("uid") ?? "";
  const router = useRouter();
  const act = useAction();
  const { data, error, loading, reload } = useLoad(() => load(uid), uid);
  const [dialog, setDialog] = useState<null | "ban" | "password" | "warn" | "reset">(null);

  if (loading && !data) return <Loading />;
  if (error) return <ErrorNote error={error} />;
  if (!data) return <Empty title="No such account" hint="It may have been deleted." />;
  const { user: u, posts, reports, community, history } = data;

  const lift = () =>
    act(
      { title: `Lift the ban on @${u.username}?`, body: "They can sign in again.", action: "Lift ban" },
      () => adminCall("ban", { uid: u.id, banned: false }),
      `@${u.username} can sign in again.`,
    ).then((done) => done && reload());
  const dialogProps = { user: u, onClose: () => setDialog(null), onDone: () => { setDialog(null); reload(); } };

  const remove = () =>
    act(
      { title: `Delete @${u.username}'s account?`, body: "Their profile, trades, posts, comments, likes, messages and memberships are erased, then their sign-in. This cannot be undone.", action: "Delete account", danger: true },
      () => adminCall("deleteUser", { uid: u.id, username: u.username }),
      `@${u.username}'s account is deleted.`,
    ).then((done) => done && router.replace("/users/"));

  const leave = () =>
    community &&
    act(
      { title: `Remove @${u.username} from ${community.name}?`, body: "They leave the community and its chat. They can join again unless it is locked.", action: "Remove", danger: true },
      () => adminCall("community", { communityId: community.id, op: "remove", uid: u.id }),
      `@${u.username} is out of ${community.name}.`,
    ).then((done) => done && reload());

  const deletePost = (p: PostDoc) =>
    act(
      { title: "Delete this post?", body: "It goes with its likes and comments, for everyone.", action: "Delete post", danger: true },
      () => adminCall("deletePost", { postId: p.id }),
      "Post deleted.",
    ).then((done) => done && reload());

  return (
    <>
      {dialog === "ban" && <BanDialog {...dialogProps} />}
      {dialog === "password" && <PasswordDialog {...dialogProps} />}
      {dialog === "warn" && <WarnDialog {...dialogProps} />}
      {dialog === "reset" && <ResetDialog {...dialogProps} />}
      <Link href="/users/" className="mb-4 inline-block text-sm text-muted hover:text-ink">← All users</Link>
      <div className="mb-6 flex flex-wrap items-center gap-4">
        <Avatar id={u.avatarId} size={64} />
        <div className="min-w-0 flex-1">
          <PageHeader
            title={u.displayName}
            subtitle={
              <span className="flex flex-wrap items-center gap-2">
                @{u.username} · joined {dateLabel(u.createdAt)} · {u.language === "en" ? "English" : "Bangla"}
                {u.banned && <Badge tone="bad">{u.bannedUntil ? `Banned until ${dateTime(u.bannedUntil)}` : "Banned"}</Badge>}
                {u.ranked && <Badge tone="good">Ranked</Badge>}
              </span>
            }
            actions={
              <>
                <Button onClick={() => setDialog("warn")}>Warn</Button>
                <Button onClick={() => setDialog("password")}>Reset password</Button>
                <Button onClick={() => setDialog("reset")}>Fix name or picture</Button>
                {u.banned ? <Button onClick={lift}>Lift ban</Button> : <Button variant="danger" onClick={() => setDialog("ban")}>Ban</Button>}
                <Button variant="danger" onClick={remove}>Delete account</Button>
              </>
            }
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Stat label="Discipline score" value={u.ranked ? Math.round(u.disciplineScore ?? 0) : "—"} hint={u.ranked ? "On the leaderboard" : "Not ranked yet"} />
        <Stat label="Closed trades" value={u.tradeCount ?? 0} hint={`Win rate ${Math.round((u.winRate ?? 0) * 100)}%`} />
        <Stat label="Total R" value={rText(u.totalR ?? 0)} hint={`Badge points ${u.badgePoints ?? 0}`} />
        <Stat label="Journal streak" value={`${u.journalStreak ?? 0} days`} hint={u.weekTrades ? `${u.weekTrades} trades this week` : "No trades this week"} />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <div className="flex min-w-0 flex-col gap-6 lg:col-span-2">
          <Card title={`Posts · ${posts.length}`} flush>
            {posts.length === 0 ? (
              <Empty title="No posts" />
            ) : (
              <ul className="divide-y divide-line-soft">
                {posts.map((p) => (
                  <li key={p.id} className="flex items-start gap-4 px-5 py-4">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2 text-xs text-muted">
                        <Badge>{p.kind === "question" ? "Question" : p.kind === "rank" ? "Rank" : `${p.symbol ?? "Trade"} ${rText(p.rMultiple)}`}</Badge>
                        <span>{p.community === "global" ? "Global" : "Community"}</span>
                        <span>· {timeAgo(p.postedAt)}</span>
                        <span>· {p.claps ?? 0} likes · {p.commentCount ?? 0} comments</span>
                      </div>
                      <p className="mt-1.5 text-sm leading-relaxed break-words text-ink">{p.lesson}</p>
                    </div>
                    <Button size="sm" variant="ghost" onClick={() => deletePost(p)}>Delete</Button>
                  </li>
                ))}
              </ul>
            )}
          </Card>
          <Card title={`Reports about them · ${reports.length}`} flush>
            {reports.length === 0 ? (
              <Empty title="Nobody has reported them" />
            ) : (
              <ul className="divide-y divide-line-soft">
                {reports.map((r) => (
                  <li key={r.id} className="flex flex-wrap items-center gap-3 px-5 py-3 text-sm">
                    <Badge tone={r.status === "open" ? "warn" : "neutral"}>{r.status}</Badge>
                    <span className="text-ink">{REPORT_REASONS[r.reason] ?? r.reason}</span>
                    <span className="text-muted">· {KINDS[r.kind] ?? r.kind} · {timeAgo(r.createdAt)}</span>
                    {r.quote && <span className="w-full truncate text-muted">“{r.quote}”</span>}
                  </li>
                ))}
              </ul>
            )}
          </Card>
          <Card title={`What admins did · ${history.length}`} flush>
            <ActivityList entries={history} empty="No admin has done anything to this account" />
          </Card>
        </div>
        <div className="flex min-w-0 flex-col gap-6">
          <Card title="Community">
            {community ? (
              <div className="flex items-center gap-3">
                <CommunityPicture id={community.avatarId} name={community.name} size={44} />
                <div className="min-w-0 flex-1">
                  <Link href={`/communities/view/?id=${community.id}`} className="block truncate text-sm font-medium text-ink-strong hover:underline">{community.name}</Link>
                  <div className="text-xs text-muted">{community.createdBy === u.id ? "Its admin" : "Member"}</div>
                </div>
                {community.createdBy !== u.id && <Button size="sm" variant="ghost" onClick={leave}>Remove</Button>}
              </div>
            ) : (
              <p className="text-sm text-muted">Not in a community.</p>
            )}
          </Card>
          <Card title="Achievements">
            {(u.achievements ?? []).length === 0 ? (
              <p className="text-sm text-muted">None yet.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {(u.achievements ?? []).map((a) => <Badge key={a} tone="dark">{ACHIEVEMENTS[a] ?? a}</Badge>)}
              </div>
            )}
          </Card>
          <Card title="Account">
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
              <dt className="text-muted">User ID</dt>
              <dd className="truncate font-mono text-xs leading-5 text-ink">{u.id}</dd>
              <dt className="text-muted">Gender</dt>
              <dd className="text-ink capitalize">{u.gender ?? "—"}</dd>
              <dt className="text-muted">Scores updated</dt>
              <dd className="text-ink">{timeAgo(u.statsUpdatedAt)}</dd>
            </dl>
          </Card>
        </div>
      </div>
    </>
  );
}

export default function Page() {
  return (
    <Suspense fallback={<Loading />}>
      <UserView />
    </Suspense>
  );
}
