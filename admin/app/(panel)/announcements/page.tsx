"use client";

import { collection, getDocs, limit, orderBy, query } from "firebase/firestore";
import { useState } from "react";
import { useAction } from "@/components/feedback";
import { Button, Card, Empty, ErrorNote, Loading, PageHeader, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allCommunities, allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateTime, timeAgo } from "@/lib/format";
import { rows, type When } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

// As the worker allows them (worker/src/admin.js).
const TITLE_MAX = 80;
const BODY_MAX = 300;

type Line = { title: string; body: string };
type Announcement = { id: string; bn: Line; en: Line; sentBy: string; sentAt?: When; communityId?: string };

async function load() {
  const [sent, users, communities] = await Promise.all([
    getDocs(query(collection(db, "announcements"), orderBy("sentAt", "desc"), limit(50))),
    allUsers(),
    allCommunities(),
  ]);
  return {
    sent: rows<Announcement>(sent),
    names: new Map(users.map((u) => [u.id, u.username])),
    communities: communities.sort((a, b) => a.name.localeCompare(b.name)),
  };
}

const LANGUAGES = [
  { id: "bn", label: "বাংলা", hint: "For people using the app in Bangla", title: "শিরোনাম", body: "কী বলতে চান" },
  { id: "en", label: "English", hint: "For people using the app in English", title: "Title", body: "Message" },
] as const;

const EMPTY = { bn: { title: "", body: "" }, en: { title: "", body: "" } };

function Counter({ n, max }: { n: number; max: number }) {
  return <span className={cx("tabular text-xs", n > max ? "text-bad" : "text-faint")}>{n}/{max}</span>;
}

/** Roughly how it lands on a phone's lock screen. */
function Preview({ line, title, body }: { line: Line; title: string; body: string }) {
  return (
    <div className="flex gap-3 rounded-2xl bg-sunken p-3.5">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/icon.png" alt="" className="size-9 shrink-0 rounded-[10px]" />
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2 text-xs text-muted">
          <span className="font-medium uppercase tracking-wide">Forex Social</span>
          <span>now</span>
        </div>
        <div className="mt-0.5 truncate text-sm font-semibold text-ink-strong">{line.title.trim() || title}</div>
        <div className="line-clamp-3 text-sm break-words text-ink">{line.body.trim() || body}</div>
      </div>
    </div>
  );
}

export default function AnnouncementsPage() {
  const act = useAction();
  const { data, error, loading, reload } = useLoad(load);
  const [draft, setDraft] = useState<{ bn: Line; en: Line }>(EMPTY);
  const [to, setTo] = useState("");
  const community = data?.communities.find((c) => c.id === to);
  const communityName = (id?: string) => data?.communities.find((c) => c.id === id)?.name ?? "a community";

  const fine = (l: Line) => l.title.trim() && l.body.trim() && l.title.length <= TITLE_MAX && l.body.length <= BODY_MAX;
  const ready = fine(draft.bn) && fine(draft.en);
  const set = (lang: "bn" | "en", field: keyof Line, value: string) =>
    setDraft((d) => ({ ...d, [lang]: { ...d[lang], [field]: value } }));

  const send = () =>
    act(
      community
        ? {
            title: `Send to ${community.name}?`,
            body: `Every member of ${community.name} with notifications on gets it now, in their language. Tapping it opens the community's chat. It can't be taken back once sent.`,
            action: "Send now",
          }
        : {
            title: "Send to everyone?",
            body: "Every phone with notifications on gets it now — the Bangla one on phones set to Bangla, the English one on the rest. A notification can't be taken back once sent.",
            action: "Send now",
          },
      () => adminCall("broadcast", community ? { ...draft, communityId: community.id } : draft),
      community ? `Sent to the members of ${community.name}.` : "Sent to every phone.",
    ).then((ok) => {
      if (!ok) return;
      setDraft(EMPTY);
      reload();
    });

  return (
    <>
      <PageHeader title="Announcements" subtitle="A notification to everyone, or to one community: an update, a new feature, a market holiday, a live session." />
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Card title="New announcement">
          <label className="mb-6 flex flex-col gap-1.5">
            <span className="text-xs font-medium text-muted">Send to</span>
            <select className={inputClass} value={to} onChange={(e) => setTo(e.target.value)}>
              <option value="">Everyone</option>
              {(data?.communities ?? []).map((c) => <option key={c.id} value={c.id}>{c.name} · {c.memberCount ?? 0} members</option>)}
            </select>
          </label>
          <div className="grid gap-6 md:grid-cols-2">
            {LANGUAGES.map((l) => (
              <div key={l.id} className="flex min-w-0 flex-col gap-3">
                <div>
                  <div className="text-sm font-semibold text-ink-strong">{l.label}</div>
                  <div className="text-xs text-muted">{l.hint}</div>
                </div>
                <label className="flex flex-col gap-1.5">
                  <span className="flex justify-between text-xs font-medium text-muted">
                    {l.title} <Counter n={draft[l.id].title.length} max={TITLE_MAX} />
                  </span>
                  <input className={inputClass} lang={l.id} value={draft[l.id].title} onChange={(e) => set(l.id, "title", e.target.value)} />
                </label>
                <label className="flex flex-col gap-1.5">
                  <span className="flex justify-between text-xs font-medium text-muted">
                    {l.body} <Counter n={draft[l.id].body.length} max={BODY_MAX} />
                  </span>
                  <textarea className={cx(inputClass, "h-28 resize-y py-2.5")} lang={l.id} value={draft[l.id].body} onChange={(e) => set(l.id, "body", e.target.value)} />
                </label>
                <Preview line={draft[l.id]} title={l.title} body={l.body} />
              </div>
            ))}
          </div>
          <div className="mt-6 flex flex-wrap items-center justify-between gap-3 border-t border-line-soft pt-5">
            <p className="text-xs text-muted">Both languages are needed, so nobody gets one they can&apos;t read.</p>
            <div className="flex gap-2">
              {(draft.bn.title || draft.bn.body || draft.en.title || draft.en.body) && (
                <Button variant="ghost" onClick={() => setDraft(EMPTY)}>Clear</Button>
              )}
              <Button variant="primary" disabled={!ready} onClick={send}>{community ? "Send to the community" : "Send to everyone"}</Button>
            </div>
          </div>
        </Card>

        <Card title="Sent before" className="h-fit" flush>
          <ErrorNote error={error} />
          {loading && !data ? (
            <Loading />
          ) : !data?.sent.length ? (
            <Empty title="Nothing sent yet" hint="Announcements you send show up here." />
          ) : (
            <ul className="divide-y divide-line-soft">
              {data.sent.map((a) => (
                <li key={a.id} className="px-5 py-4">
                  <div className="text-sm font-medium text-ink-strong">{a.bn.title}</div>
                  <p className="mt-0.5 line-clamp-2 text-sm break-words text-muted">{a.bn.body}</p>
                  <div className="mt-2 text-sm text-ink">{a.en.title}</div>
                  <p className="mt-0.5 line-clamp-2 text-sm break-words text-muted">{a.en.body}</p>
                  <div className="mt-2 text-xs text-faint" title={dateTime(a.sentAt)}>
                    To {a.communityId ? communityName(a.communityId) : "everyone"} · {timeAgo(a.sentAt)} by @{data.names.get(a.sentBy) ?? "an admin"}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </>
  );
}
