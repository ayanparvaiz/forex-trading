"use client";

import { collection, doc, getDoc, getDocs, limit, orderBy, query } from "firebase/firestore";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { useAction } from "@/components/feedback";
import { Avatar, Badge, Button, Card, CommunityPicture, Empty, ErrorNote, Loading, PageHeader, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allCommunities, allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateTime, rText, timeAgo } from "@/lib/format";
import { rows, type MessageDoc } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

const PAGE = 100;

async function loadRooms() {
  const [communities, users] = await Promise.all([allCommunities(), allUsers()]);
  return {
    communities: communities.sort((a, b) => a.name.localeCompare(b.name)),
    users: new Map(users.map((u) => [u.id, u])),
  };
}

async function loadMessages(roomId: string, n: number) {
  const [room, snap] = await Promise.all([
    getDoc(doc(db, "rooms", roomId)),
    getDocs(query(collection(db, "rooms", roomId, "messages"), orderBy("sentAt", "desc"), limit(n))),
  ]);
  return { memberCount: room.data()?.memberCount as number | undefined, messages: rows<MessageDoc>(snap), full: snap.size === n };
}

/** What a message carries besides its words, in a line. */
function attachmentLine(a: MessageDoc["attachment"]): string | null {
  if (!a) return null;
  switch (a.type) {
    case "post":
      return "Shared a post";
    case "poll":
      return `Poll: ${a.question} — ${((a.options as string[]) ?? []).join(" / ")}`;
    case "trade":
      return `Trade card: ${a.symbol ?? ""} ${a.direction ?? ""} ${rText(a.r)}`;
    case "rank":
      return `Shared their rank: #${a.rank}, discipline ${a.score}`;
    case "community":
      return "Invited to a community";
    default:
      return `Attachment: ${a.type}`;
  }
}

function Rooms() {
  const roomId = useSearchParams().get("room") ?? "global";
  const router = useRouter();
  const act = useAction();
  const [n, setN] = useState(PAGE);
  const [search, setSearch] = useState("");
  const rooms = useLoad(loadRooms);
  const msgs = useLoad(() => loadMessages(roomId, n), `${roomId}/${n}`);

  const communities = rooms.data?.communities ?? [];
  const users = rooms.data?.users;
  const current = roomId === "global" ? null : communities.find((c) => `c_${c.id}` === roomId);
  const title = roomId === "global" ? "Global" : (current?.name ?? "Community chat");

  const open = (id: string) => {
    setN(PAGE);
    setSearch("");
    router.replace(`/rooms/?room=${id}`);
  };

  const remove = (m: MessageDoc) =>
    act(
      { title: "Remove this message?", body: "Everyone sees “Removed by admin” in its place. Its words and anything it carried go.", action: "Remove", danger: true },
      () => adminCall("removeMessage", { roomId, messageId: m.id }),
      "Message removed.",
    ).then((ok) => ok && msgs.reload());

  const q = search.trim().toLowerCase();
  const shown = (msgs.data?.messages ?? []).filter(
    (m) => !q || m.text?.toLowerCase().includes(q) || m.senderName?.toLowerCase().includes(q) || m.senderUsername?.toLowerCase().includes(q),
  );

  const roomButton = (id: string, name: string, picture: React.ReactNode) => (
    <button key={id} onClick={() => open(id)}
      className={cx(
        "flex w-full min-w-0 items-center gap-3 rounded-lg px-3 py-2 text-left text-sm transition-colors",
        id === roomId ? "bg-sunken font-medium text-ink-strong" : "text-muted hover:bg-sunken hover:text-ink",
      )}>
      {picture}
      <span className="truncate">{name}</span>
    </button>
  );

  return (
    <>
      <PageHeader title="Chat rooms" subtitle="Global and each community's chat. Private messages between two people are never shown here." />
      <ErrorNote error={rooms.error ?? msgs.error} />
      <div className="grid gap-6 lg:grid-cols-[260px_minmax(0,1fr)]">
        <select className={cx(inputClass, "lg:hidden")} value={roomId} onChange={(e) => open(e.target.value)} aria-label="Room">
          <option value="global">Global</option>
          {communities.map((c) => <option key={c.id} value={`c_${c.id}`}>{c.name}</option>)}
        </select>
        <Card className="hidden h-fit lg:block" flush>
          <div className="flex flex-col gap-1 p-2">
            {roomButton("global", "Global", <span className="grid size-7 shrink-0 place-items-center rounded-full bg-ink text-xs text-white">🌐</span>)}
            {communities.map((c) => roomButton(`c_${c.id}`, c.name, <CommunityPicture id={c.avatarId} name={c.name} size={28} />))}
          </div>
        </Card>

        <Card
          title={
            <span className="flex flex-wrap items-center gap-2">
              {title}
              {msgs.data?.memberCount != null && <span className="text-sm font-normal text-muted">· {msgs.data.memberCount} members · newest first</span>}
              {current?.locked && <Badge tone="warn">Locked</Badge>}
            </span>
          }
          actions={current && <Link href={`/communities/view/?id=${current.id}`} className="text-sm text-muted hover:text-ink">Community →</Link>}
          flush
        >
          <div className="border-b border-line-soft px-5 py-3">
            <input className={inputClass} placeholder="Search these messages by words or name" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          {msgs.loading && !msgs.data ? (
            <Loading />
          ) : shown.length === 0 ? (
            <Empty title={q ? "Nothing matches" : "No messages yet"} />
          ) : (
            <ul className="divide-y divide-line-soft">
              {shown.map((m) => {
                const u = users?.get(m.senderUid);
                const extra = attachmentLine(m.attachment);
                const reactions = Object.values(m.reactions ?? {});
                return (
                  <li key={m.id} className="flex gap-3 px-5 py-3.5">
                    <Link href={`/users/view/?uid=${m.senderUid}`} className="shrink-0"><Avatar id={u?.avatarId} size={34} /></Link>
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-baseline gap-x-2 text-sm">
                        <Link href={`/users/view/?uid=${m.senderUid}`} className="font-medium text-ink-strong hover:underline">
                          {m.senderName || u?.displayName || "Someone"}
                        </Link>
                        <span className="text-xs text-muted">@{m.senderUsername ?? u?.username ?? "?"}</span>
                        <span className="text-xs text-faint" title={dateTime(m.sentAt)}>{timeAgo(m.sentAt)}</span>
                      </div>
                      {m.removed ? (
                        <p className="mt-1 text-sm italic text-faint">Removed by admin</p>
                      ) : m.unsent ? (
                        <p className="mt-1 text-sm italic text-faint">Unsent by its sender</p>
                      ) : (
                        <>
                          {m.text && <p className="mt-1 whitespace-pre-wrap break-words text-sm leading-relaxed text-ink">{m.text}</p>}
                          {extra && <p className="mt-1.5 inline-block max-w-full rounded-md bg-sunken px-2.5 py-1 text-xs break-words text-muted">{extra}</p>}
                          {reactions.length > 0 && <p className="mt-1.5 text-xs text-muted">{reactions.join(" ")}</p>}
                        </>
                      )}
                    </div>
                    {!m.unsent && (
                      <Button size="sm" variant="ghost" className="shrink-0 self-start" onClick={() => remove(m)}>Remove</Button>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
          {msgs.data?.full && (
            <div className="border-t border-line-soft p-3 text-center">
              <Button size="sm" loading={msgs.loading} onClick={() => setN((x) => x + PAGE)}>Show older messages</Button>
            </div>
          )}
        </Card>
      </div>
    </>
  );
}

export default function Page() {
  return (
    <Suspense fallback={<Loading />}>
      <Rooms />
    </Suspense>
  );
}
