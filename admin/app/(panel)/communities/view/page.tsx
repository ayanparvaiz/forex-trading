"use client";

import { collection, doc, getDoc, getDocs, limit, query } from "firebase/firestore";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { useAction } from "@/components/feedback";
import { Avatar, Badge, Button, Card, CommunityPicture, Empty, ErrorNote, Loading, PageHeader, Stat, Table, td } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateLabel, dateTime, timeAgo, toDate } from "@/lib/format";
import { rows, type CommunityDoc, type When } from "@/lib/types";
import { useSession } from "@/lib/session";
import { useLoad } from "@/lib/use-load";
import { EditDialog } from "./edit-dialog";
import { EventDialog } from "./event-dialog";

type Member = { id: string; role: string; username: string; joinedAt?: When };
type Event = { id: string; title: string; description?: string; startsAt?: When; going?: string[] };

async function load(id: string) {
  const snap = await getDoc(doc(db, "communities", id));
  if (!snap.exists()) return null;
  const [members, events, users] = await Promise.all([
    getDocs(query(collection(db, "communities", id, "members"), limit(1000))),
    getDocs(query(collection(db, "communities", id, "events"), limit(50))),
    allUsers(),
  ]);
  const at = (v: unknown) => toDate(v)?.getTime() ?? 0;
  return {
    c: { id: snap.id, ...snap.data() } as CommunityDoc,
    members: rows<Member>(members).sort((a, b) => (a.role === "admin" ? -1 : b.role === "admin" ? 1 : at(a.joinedAt) - at(b.joinedAt))),
    events: rows<Event>(events).sort((a, b) => at(b.startsAt) - at(a.startsAt)),
    users: new Map(users.map((u) => [u.id, u])),
  };
}

function CommunityView() {
  const id = useSearchParams().get("id") ?? "";
  const router = useRouter();
  const act = useAction();
  const { data, error, loading, reload } = useLoad(() => load(id), id);
  const [editing, setEditing] = useState(false);
  const [planning, setPlanning] = useState(false);
  const { can } = useSession();

  if (loading && !data) return <Loading />;
  if (error) return <ErrorNote error={error} />;
  if (!data) return <Empty title="No such community" hint="It may have been deleted." />;
  const { c, members, events, users } = data;
  const admin = users.get(c.createdBy);

  const lock = (locked: boolean) =>
    act(
      locked
        ? { title: `Lock ${c.name}?`, body: "Nobody new can join, and only its admin can write in its chat and feed.", action: "Lock" }
        : null,
      () => adminCall("community", { communityId: c.id, op: locked ? "lock" : "unlock" }),
      locked ? `${c.name} is locked.` : `${c.name} is open again.`,
    ).then((ok) => ok && reload());

  const remove = (m: Member) =>
    act(
      { title: `Remove @${m.username}?`, body: "They leave the community and its chat.", action: "Remove", danger: true },
      () => adminCall("community", { communityId: c.id, op: "remove", uid: m.id }),
      `@${m.username} removed.`,
    ).then((ok) => ok && reload());

  const transfer = (m: Member) =>
    act(
      { title: `Make @${m.username} the admin of ${c.name}?`, body: `They run it from now on. @${admin?.username ?? "the old admin"} stays in it as a member.`, action: "Make admin" },
      () => adminCall("community", { communityId: c.id, op: "transfer", uid: m.id }),
      `@${m.username} runs ${c.name} now.`,
    ).then((ok) => ok && reload());

  const dropEvent = (e: Event) =>
    act(
      { title: `Take down “${e.title}”?`, body: "It goes from the community, with who said they were going.", action: "Take down", danger: true },
      () => adminCall("event", { communityId: c.id, op: "delete", eventId: e.id }),
      "Event taken down.",
    ).then((ok) => ok && reload());

  const destroy = () =>
    act(
      { title: `Delete ${c.name}?`, body: `All ${c.memberCount ?? 0} members leave it. Its chat, feed posts, events and name go too. This cannot be undone.`, action: "Delete community", danger: true },
      () => adminCall("community", { communityId: c.id, op: "delete" }),
      `${c.name} is deleted.`,
    ).then((ok) => ok && router.replace("/communities/"));

  return (
    <>
      {planning && <EventDialog c={c} onClose={() => setPlanning(false)} onDone={() => { setPlanning(false); reload(); }} />}
      {editing && <EditDialog c={c} onClose={() => setEditing(false)} onDone={() => { setEditing(false); reload(); }} />}
      <Link href="/communities/" className="mb-4 inline-block text-sm text-muted hover:text-ink">← All communities</Link>
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center">
        <CommunityPicture id={c.avatarId} name={c.name} size={64} />
        <div className="min-w-0 flex-1">
          <PageHeader
            title={c.name}
            subtitle={
              <span className="flex flex-wrap items-center gap-2">
                Started {dateLabel(c.createdAt)} · admin
                <Link className="text-ink hover:underline" href={`/users/view/?uid=${c.createdBy}`}>@{admin?.username ?? "unknown"}</Link>
                {c.locked && <Badge tone="warn">Locked</Badge>}
              </span>
            }
            actions={
              <>
                <Link href={`/rooms/?room=c_${c.id}`}><Button>Open its chat</Button></Link>
                {can("community") && (
                  <>
                    <Button onClick={() => setEditing(true)}>Edit</Button>
                    {c.locked ? <Button onClick={() => lock(false)}>Unlock</Button> : <Button onClick={() => lock(true)}>Lock</Button>}
                    <Button variant="danger" onClick={destroy}>Delete community</Button>
                  </>
                )}
              </>
            }
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <Stat label="Members" value={c.memberCount ?? 0} />
        <Stat label="Slow mode" value={(c.slowSeconds ?? 0) > 0 ? `${c.slowSeconds}s` : "Off"} hint="Between one member's messages" />
        <Stat label="Events" value={events.length} />
        <Stat label="Champion" value={(c.titles ?? []).length ? `🏆 ×${c.titles?.length}` : "—"} hint={(c.titles ?? []).join(", ") || "Not yet"} />
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <div className="min-w-0 lg:col-span-2">
          <Card title={`Members · ${members.length}`} flush>
            <Table head={["Member", "Role", "Joined", ""]}>
              {members.map((m) => {
                const u = users.get(m.id);
                return (
                  <tr key={m.id}>
                    <td className={td}>
                      <Link href={`/users/view/?uid=${m.id}`} className="flex min-w-[180px] items-center gap-3">
                        <Avatar id={u?.avatarId} size={32} />
                        <span className="min-w-0">
                          <span className="block truncate font-medium text-ink-strong">{u?.displayName ?? m.username}</span>
                          <span className="block truncate text-xs text-muted">@{m.username}</span>
                        </span>
                      </Link>
                    </td>
                    <td className={td}>
                      {m.role === "admin" ? <Badge tone="dark">Admin</Badge> : m.role === "moderator" ? <Badge tone="good">Moderator</Badge> : <span className="text-muted">Member</span>}
                    </td>
                    <td className={`${td} whitespace-nowrap text-muted`}>{dateLabel(m.joinedAt)}</td>
                    <td className={`${td} text-right`}>
                      {m.role !== "admin" && can("community") && (
                        <span className="flex justify-end gap-1">
                          <Button size="sm" variant="ghost" onClick={() => transfer(m)}>Make admin</Button>
                          <Button size="sm" variant="ghost" onClick={() => remove(m)}>Remove</Button>
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </Table>
          </Card>
        </div>
        <div className="flex min-w-0 flex-col gap-6">
          <Card title="About">
            <p className="text-sm leading-relaxed break-words text-ink">{c.description || <span className="text-muted">No description.</span>}</p>
          </Card>
          <Card title="Rules">
            {(c.rules ?? []).length ? (
              <ol className="list-decimal space-y-1.5 pl-5 text-sm text-ink">
                {c.rules?.map((r, i) => <li key={i} className="break-words">{r}</li>)}
              </ol>
            ) : (
              <p className="text-sm text-muted">No rules written.</p>
            )}
          </Card>
          <Card title="Events" flush actions={can("event") && <Button size="sm" onClick={() => setPlanning(true)}>New event</Button>}>
            {events.length === 0 ? (
              <Empty title="No events" />
            ) : (
              <ul className="divide-y divide-line-soft">
                {events.map((e) => (
                  <li key={e.id} className="flex items-start gap-3 px-5 py-3">
                    <div className="min-w-0 flex-1">
                      <div className="text-sm font-medium break-words text-ink-strong">{e.title}</div>
                      <div className="text-xs text-muted">{dateTime(e.startsAt)} · {(e.going ?? []).length} going · {timeAgo(e.startsAt)}</div>
                    </div>
                    {can("event") && <Button size="sm" variant="ghost" onClick={() => dropEvent(e)}>Take down</Button>}
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}

export default function Page() {
  return (
    <Suspense fallback={<Loading />}>
      <CommunityView />
    </Suspense>
  );
}
