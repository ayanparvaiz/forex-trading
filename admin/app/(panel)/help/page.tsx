"use client";

import { collection, doc, getDoc, getDocs, limit, query, where } from "firebase/firestore";
import Link from "next/link";
import { useState } from "react";
import { useAction, useFeedback } from "@/components/feedback";
import { AdminsOnly, Avatar, Badge, Button, Card, Empty, ErrorNote, Loading, PageHeader, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateTime, timeAgo, toDate } from "@/lib/format";
import { useSession } from "@/lib/session";
import type { UserDoc, When } from "@/lib/types";
import { useLoad } from "@/lib/use-load";
import { PasswordDialog } from "../users/view/people-dialogs";

type Message = { id: string; uid: string; username: string; text: string; createdAt?: When; status: string; reply?: string; repliedAt?: When; repliedBy?: string };
type Request = { id: string; uid: string; username: string; contact: string; note?: string; createdAt?: When; status: string; handledBy?: string; handledAt?: When };

const newest = (a: { createdAt?: When }, b: { createdAt?: When }) => (toDate(b.createdAt)?.getTime() ?? 0) - (toDate(a.createdAt)?.getTime() ?? 0);

const TABS = [
  { id: "messages", label: "Messages" },
  { id: "passwords", label: "Password requests" },
] as const;
type Tab = (typeof TABS)[number]["id"];

async function load(tab: Tab, open: boolean) {
  const statuses = open ? ["open"] : tab === "messages" ? ["answered", "closed"] : ["done", "dismissed"];
  const [snap, users] = await Promise.all([
    getDocs(query(collection(db, tab === "messages" ? "support" : "helpRequests"), where("status", "in", statuses), limit(200))),
    allUsers(),
  ]);
  return {
    items: snap.docs.map((d) => ({ id: d.id, ...d.data() }) as Message & Request),
    users: new Map(users.map((u) => [u.id, u])),
  };
}

function Person({ uid, username, users }: { uid: string; username: string; users: Map<string, UserDoc> }) {
  const u = users.get(uid);
  return (
    <Link href={`/users/view/?uid=${uid}`} className="flex min-w-0 items-center gap-2.5">
      <Avatar id={u?.avatarId} size={30} />
      <span className="min-w-0">
        <span className="block truncate text-sm font-medium text-ink-strong">{u?.displayName ?? username}</span>
        <span className="block truncate text-xs text-muted">@{username}{!u && " · account gone"}</span>
      </span>
    </Link>
  );
}

function MessageCard({ m, users, onChange }: { m: Message; users: Map<string, UserDoc>; onChange: () => void }) {
  const act = useAction();
  const { toast } = useFeedback();
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const send = async () => {
    setBusy(true);
    try {
      const r = await adminCall<{ phones: number }>("reply", { id: m.id, text });
      toast(r.phones ? `Answered; it reached @${m.username}'s phone.` : `Answered. @${m.username} sees it in the app (their notifications are off).`);
      setText("");
      onChange();
    } catch (e) {
      toast(e instanceof Error ? e.message : "That did not work.", "bad");
    } finally {
      setBusy(false);
    }
  };
  return (
    <Card>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <Person uid={m.uid} username={m.username} users={users} />
        <span className="flex items-center gap-2 text-xs text-faint">
          <Badge tone={m.status === "open" ? "warn" : m.status === "answered" ? "good" : "neutral"}>{m.status}</Badge>
          <span title={dateTime(m.createdAt)}>{timeAgo(m.createdAt)}</span>
        </span>
      </div>
      <p className="mt-3 text-[15px] leading-relaxed whitespace-pre-wrap break-words text-ink">{m.text}</p>
      {m.reply && (
        <div className="mt-3 rounded-xl bg-sunken px-4 py-3 text-sm">
          <div className="text-xs text-muted">Answered {timeAgo(m.repliedAt)} by @{users.get(m.repliedBy ?? "")?.username ?? "an admin"}</div>
          <p className="mt-1 whitespace-pre-wrap break-words text-ink">{m.reply}</p>
        </div>
      )}
      {m.status !== "closed" && (
        <div className="mt-4 flex flex-col gap-2 border-t border-line-soft pt-4">
          <textarea className={cx(inputClass, "h-20 resize-y py-2.5")} placeholder={m.reply ? "Answer again" : "Your answer — it goes to their phone"} value={text} onChange={(e) => setText(e.target.value)} />
          <div className="flex flex-wrap justify-end gap-2">
            <Button size="sm" variant="ghost" onClick={() => act(null, () => adminCall("closeSupport", { id: m.id }), "Put away.").then((ok) => ok && onChange())}>Put away</Button>
            <Button size="sm" variant="primary" loading={busy} disabled={!text.trim() || text.length > 1000} onClick={send}>Send answer</Button>
          </div>
        </div>
      )}
    </Card>
  );
}

function RequestCard({ r, users, onChange }: { r: Request; users: Map<string, UserDoc>; onChange: () => void }) {
  const act = useAction();
  const [user, setUser] = useState<UserDoc | null>(null);
  const settle = (status: "done" | "dismissed") =>
    act(null, () => adminCall("help", { id: r.id, status }), status === "done" ? "Marked done." : "Dismissed.").then((ok) => ok && onChange());
  const openPassword = async () => {
    const snap = await getDoc(doc(db, "users", r.uid));
    if (snap.exists()) setUser({ id: snap.id, ...snap.data() } as UserDoc);
  };
  return (
    <Card>
      {user && <PasswordDialog user={user} onClose={() => setUser(null)} onDone={() => setUser(null)} />}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <Person uid={r.uid} username={r.username} users={users} />
        <span className="flex items-center gap-2 text-xs text-faint">
          <Badge tone={r.status === "open" ? "warn" : r.status === "done" ? "good" : "neutral"}>{r.status}</Badge>
          <span title={dateTime(r.createdAt)}>{timeAgo(r.createdAt)}</span>
        </span>
      </div>
      <dl className="mt-3 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-sm">
        <dt className="text-muted">Reach them at</dt>
        <dd className="font-medium break-all text-ink-strong">{r.contact}</dd>
        {r.note && (
          <>
            <dt className="text-muted">They said</dt>
            <dd className="break-words text-ink">{r.note}</dd>
          </>
        )}
      </dl>
      {r.status === "open" ? (
        <div className="mt-4 flex flex-col gap-3 border-t border-line-soft pt-4">
          <p className="text-xs text-muted">
            Anyone can ask in someone&apos;s name. Before setting a password, make sure it&apos;s really them — for example, ask them something only they would know about their account.
          </p>
          <div className="flex flex-wrap justify-end gap-2">
            <Button size="sm" variant="ghost" onClick={() => settle("dismissed")}>Dismiss</Button>
            <Button size="sm" onClick={() => settle("done")}>Mark done</Button>
            {users.has(r.uid) && <Button size="sm" variant="primary" onClick={openPassword}>Set a new password</Button>}
          </div>
        </div>
      ) : (
        <p className="mt-3 text-xs text-faint">{r.status === "done" ? "Done" : "Dismissed"} {timeAgo(r.handledAt)} by @{users.get(r.handledBy ?? "")?.username ?? "an admin"}</p>
      )}
    </Card>
  );
}

function Inbox() {
  const [tab, setTab] = useState<Tab>("messages");
  const [open, setOpen] = useState(true);
  const { data, error, loading, reload } = useLoad(() => load(tab, open), `${tab}/${open}`);
  const items = (data?.items ?? []).sort(newest);
  const chip = (on: boolean) => cx("h-9 rounded-lg px-3.5 text-[13px] font-medium", on ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink");
  return (
    <>
      <div className="mb-4 flex flex-wrap items-center gap-1.5">
        {TABS.map((t) => (
          <button key={t.id} className={chip(tab === t.id)} onClick={() => setTab(t.id)}>{t.label}</button>
        ))}
        <span className="mx-1 h-6 w-px bg-line" aria-hidden />
        <button className={chip(open)} onClick={() => setOpen(true)}>Waiting</button>
        <button className={chip(!open)} onClick={() => setOpen(false)}>Dealt with</button>
      </div>
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : items.length === 0 ? (
        <Card>
          <Empty
            title={open ? "Nothing waiting" : "Nothing here yet"}
            hint={tab === "messages" ? "What people write to the admins from the app shows up here." : "People locked out of their account ask here, from the app's sign-in screen."}
          />
        </Card>
      ) : (
        <div className="flex flex-col gap-4">
          {tab === "messages"
            ? items.map((m) => <MessageCard key={m.id} m={m as Message} users={data!.users} onChange={reload} />)
            : items.map((r) => <RequestCard key={r.id} r={r as Request} users={data!.users} onChange={reload} />)}
        </div>
      )}
    </>
  );
}

export default function Page() {
  const { can } = useSession();
  return (
    <>
      <PageHeader title="Help inbox" subtitle="Messages people write to the admins in the app, and requests from people locked out of their account." />
      {can("reply") ? <Inbox /> : <AdminsOnly />}
    </>
  );
}
