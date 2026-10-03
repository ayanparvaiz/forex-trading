"use client";

import { collection, getDocs, limit, query, where } from "firebase/firestore";
import Link from "next/link";
import { useState } from "react";
import { useAction } from "@/components/feedback";
import { Badge, Button, Card, cx, Empty, ErrorNote, Loading, PageHeader } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateTime, timeAgo, toDate } from "@/lib/format";
import { KINDS, REPORT_REASONS } from "@/lib/labels";
import { rows, type ReportDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

const TABS = [
  { id: "open", label: "Open" },
  { id: "resolved", label: "Resolved" },
  { id: "dismissed", label: "Dismissed" },
] as const;
type Status = (typeof TABS)[number]["id"];

const isRoom = (id?: string) => id === "global" || (id ?? "").startsWith("c_");

async function load(status: Status) {
  const [snap, users] = await Promise.all([
    getDocs(query(collection(db, "reports"), where("status", "==", status), limit(300))),
    allUsers(),
  ]);
  const names = new Map(users.map((u) => [u.id, u.username]));
  const reports = rows<ReportDoc>(snap).sort(
    (a, b) => (toDate(b.createdAt)?.getTime() ?? 0) - (toDate(a.createdAt)?.getTime() ?? 0),
  );
  return { reports, names };
}

export default function ReportsPage() {
  const [status, setStatus] = useState<Status>("open");
  const { data, error, loading, reload } = useLoad(() => load(status), status);
  const act = useAction();

  const settle = (r: ReportDoc, to: Status, done: string) =>
    act(null, () => adminCall("resolveReport", { reportId: r.id, status: to }), done).then((ok) => ok && reload());

  // Acting on what was reported settles the report too.
  const andResolve = (r: ReportDoc) => adminCall("resolveReport", { reportId: r.id, status: "resolved" });

  const deletePost = (r: ReportDoc) =>
    act(
      { title: "Delete the reported post?", body: "It goes for everyone, with its likes and comments.", action: "Delete post", danger: true },
      async () => {
        await adminCall("deletePost", { postId: r.postId });
        await andResolve(r);
      },
      "Post deleted, report resolved.",
    ).then((ok) => ok && reload());

  const deleteComment = (r: ReportDoc) =>
    act(
      { title: "Delete the reported comment?", action: "Delete comment", danger: true },
      async () => {
        await adminCall("deleteComment", { postId: r.postId, commentId: r.commentId });
        await andResolve(r);
      },
      "Comment deleted, report resolved.",
    ).then((ok) => ok && reload());

  const removeMessage = (r: ReportDoc) =>
    act(
      { title: "Take the message down?", body: "Everyone in the room sees it as removed by an admin.", action: "Remove message", danger: true },
      async () => {
        await adminCall("removeMessage", { roomId: r.chatId, messageId: r.messageId });
        await andResolve(r);
      },
      "Message removed, report resolved.",
    ).then((ok) => ok && reload());

  const ban = (r: ReportDoc) =>
    act(
      { title: `Ban @${r.targetUsername}?`, body: "They are signed out everywhere and cannot sign in until you lift the ban.", action: "Ban", danger: true },
      async () => {
        await adminCall("ban", { uid: r.targetUid, banned: true });
        await andResolve(r);
      },
      `@${r.targetUsername} is banned, report resolved.`,
    ).then((ok) => ok && reload());

  return (
    <>
      <PageHeader title="Reports" subtitle="What people flagged in the app, newest first." />
      <div className="mb-4 flex gap-1.5">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setStatus(t.id)}
            className={cx(
              "h-9 rounded-lg px-3.5 text-[13px] font-medium",
              status === t.id ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink",
            )}
          >
            {t.label}
          </button>
        ))}
      </div>
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : !data || data.reports.length === 0 ? (
        <Card><Empty title={status === "open" ? "Nothing waiting" : `No ${status} reports`} hint={status === "open" ? "New reports from the app show up here." : undefined} /></Card>
      ) : (
        <div className="flex flex-col gap-4">
          {data.reports.map((r) => (
            <Card key={r.id}>
              <div className="flex flex-wrap items-center gap-2">
                <Badge tone={r.status === "open" ? "warn" : r.status === "resolved" ? "good" : "neutral"}>{r.status}</Badge>
                <Badge tone="dark">{REPORT_REASONS[r.reason] ?? r.reason}</Badge>
                <span className="text-sm text-muted">
                  {KINDS[r.kind] ?? r.kind} by{" "}
                  <Link className="font-medium text-ink hover:underline" href={`/users/view/?uid=${r.targetUid}`}>@{r.targetUsername}</Link>
                  {" · reported by "}
                  <Link className="text-ink hover:underline" href={`/users/view/?uid=${r.reporterUid}`}>@{data.names.get(r.reporterUid) ?? "someone"}</Link>
                  {" · "}
                  <span title={dateTime(r.createdAt)}>{timeAgo(r.createdAt)}</span>
                </span>
              </div>
              {r.quote && (
                <blockquote className="mt-4 rounded-lg border-l-2 border-ink/30 bg-sunken px-4 py-3 text-sm leading-relaxed break-words text-ink">
                  {r.quote}
                </blockquote>
              )}
              {r.note && <p className="mt-3 text-sm text-muted">Their note: “{r.note}”</p>}
              {r.kind === "message" && !isRoom(r.chatId) && (
                <p className="mt-3 text-xs text-faint">In a private chat between two people, which admins do not read. Ban the sender if the message warrants it.</p>
              )}
              <div className="mt-4 flex flex-wrap gap-2 border-t border-line-soft pt-4">
                {r.status === "open" ? (
                  <>
                    {r.kind === "post" && r.postId && <Button size="sm" variant="danger" onClick={() => deletePost(r)}>Delete post</Button>}
                    {r.kind === "comment" && r.postId && r.commentId && <Button size="sm" variant="danger" onClick={() => deleteComment(r)}>Delete comment</Button>}
                    {r.kind === "message" && isRoom(r.chatId) && r.messageId && <Button size="sm" variant="danger" onClick={() => removeMessage(r)}>Remove message</Button>}
                    <Button size="sm" variant="danger" onClick={() => ban(r)}>Ban @{r.targetUsername}</Button>
                    <Button size="sm" onClick={() => settle(r, "resolved", "Report resolved.")}>Mark resolved</Button>
                    <Button size="sm" variant="ghost" onClick={() => settle(r, "dismissed", "Report dismissed.")}>Dismiss</Button>
                  </>
                ) : (
                  <>
                    <span className="self-center text-xs text-muted">
                      {r.status === "resolved" ? "Resolved" : "Dismissed"} {timeAgo(r.resolvedAt)} by @{data.names.get(r.resolvedBy ?? "") ?? "an admin"}
                    </span>
                    <Button size="sm" variant="ghost" onClick={() => settle(r, "open", "Report opened again.")}>Open again</Button>
                  </>
                )}
              </div>
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
