"use client";

import { doc, getDoc } from "firebase/firestore";
import Link from "next/link";
import { useState } from "react";
import { Field } from "@/components/dialog";
import { useAction } from "@/components/feedback";
import { Badge, Button, Card, ErrorNote, Loading, PageHeader, cx, inputClass, AdminsOnly } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { db } from "@/lib/firebase";
import { timeAgo } from "@/lib/format";
import type { PostDoc, When } from "@/lib/types";
import { useSession } from "@/lib/session";
import { useLoad } from "@/lib/use-load";

type Line = { title: string; body: string };
type AppConfig = {
  maintenance?: { on: boolean; bn: string; en: string };
  minBuild?: number;
  updateUrl?: string;
  banner?: { on: boolean; id: string; tone: "info" | "warn"; bn: Line; en: Line };
  pinnedPostId?: string;
  updatedAt?: When;
};

// The build the app in this repository is: read from app/pubspec.yaml as the
// panel is built (next.config.ts).
const CURRENT_BUILD = Number(process.env.NEXT_PUBLIC_APP_BUILD ?? 0);

async function load() {
  const [snap, moderation] = await Promise.all([getDoc(doc(db, "config", "app")), getDoc(doc(db, "config", "moderation"))]);
  const config = (snap.data() ?? {}) as AppConfig;
  const pinned = config.pinnedPostId ? await getDoc(doc(db, "posts", config.pinnedPostId)) : null;
  const hideAt = moderation.data()?.autoHideAt;
  return {
    config,
    pinned: pinned?.exists() ? ({ id: pinned.id, ...pinned.data() } as PostDoc) : null,
    // As the worker reads it (worker/src/admin-cron.js, AUTO_HIDE_AT).
    autoHideAt: typeof hideAt === "number" ? hideAt : 3,
    off: (moderation.data()?.off ?? {}) as Record<string, boolean>,
  };
}

function Switch({ on, onChange, label }: { on: boolean; onChange: (on: boolean) => void; label: string }) {
  return (
    <button type="button" role="switch" aria-checked={on} aria-label={label} onClick={() => onChange(!on)}
      className={cx("relative h-6 w-11 shrink-0 rounded-full transition-colors", on ? "bg-primary" : "bg-line")}>
      <span className={cx("absolute top-0.5 size-5 rounded-full bg-white shadow transition-[left]", on ? "left-[22px]" : "left-0.5")} />
    </button>
  );
}

function Maintenance({ config, onSaved }: { config: AppConfig; onSaved: () => void }) {
  const act = useAction();
  const [on, setOn] = useState(config.maintenance?.on ?? false);
  const [bn, setBn] = useState(config.maintenance?.bn ?? "সার্ভারের কাজ চলছে। একটু পরে আবার আসুন।");
  const [en, setEn] = useState(config.maintenance?.en ?? "We're doing some work on the app. Please come back in a little while.");
  const live = config.maintenance?.on ?? false;
  const save = () =>
    act(
      on && !live
        ? { title: "Close the app for everyone?", body: "Every phone shows your message instead of the app until you turn this off. Nobody can trade, post or chat meanwhile.", action: "Close the app", danger: true }
        : null,
      () => adminCall("config", { maintenance: { on, bn, en } }),
      on ? "The app is closed for maintenance." : "The app is open again.",
    ).then((ok) => ok && onSaved());
  return (
    <Card title={<span className="flex items-center gap-2">Maintenance {live ? <Badge tone="bad">App closed</Badge> : <Badge tone="good">App open</Badge>}</span>}>
      <p className="text-sm text-muted">While it is on, every phone shows this message instead of the app — before sign-in too.</p>
      <label className="mt-4 flex items-center gap-3 text-sm font-medium text-ink">
        <Switch on={on} onChange={setOn} label="Maintenance" /> Close the app for maintenance
      </label>
      <div className="mt-4 grid gap-4 md:grid-cols-2">
        <Field label="বাংলা" count={bn.length} max={300}>
          <textarea lang="bn" className={cx(inputClass, "h-20 resize-y py-2.5")} value={bn} onChange={(e) => setBn(e.target.value)} />
        </Field>
        <Field label="English" count={en.length} max={300}>
          <textarea className={cx(inputClass, "h-20 resize-y py-2.5")} value={en} onChange={(e) => setEn(e.target.value)} />
        </Field>
      </div>
      <div className="mt-4 flex justify-end">
        <Button variant={on && !live ? "danger" : "primary"} disabled={bn.length > 300 || en.length > 300} onClick={save}>Save</Button>
      </div>
    </Card>
  );
}

function ForceUpdate({ config, onSaved }: { config: AppConfig; onSaved: () => void }) {
  const act = useAction();
  const [min, setMin] = useState(String(config.minBuild ?? 0));
  const [url, setUrl] = useState(config.updateUrl ?? "");
  const n = Number(min);
  const ok = Number.isInteger(n) && n >= 0 && (url === "" || /^https:\/\/\S+$/.test(url));
  const save = () =>
    act(
      n > CURRENT_BUILD
        ? { title: `Stop every build before ${n}?`, body: `The app in the code is build ${CURRENT_BUILD}. Phones on an older build than ${n} can't go on until they update — make sure build ${n} is in the stores first.`, action: "Save", danger: true }
        : null,
      () => adminCall("config", { minBuild: n, updateUrl: url }),
      "Saved.",
    ).then((ok) => ok && onSaved());
  return (
    <Card title="Force an update">
      <p className="text-sm text-muted">
        Phones running an older build than this see “Update the app” and can&apos;t go on. 0 lets every build in. The app in this code is build <b className="text-ink">{CURRENT_BUILD}</b>.
      </p>
      <div className="mt-4 grid gap-4 md:grid-cols-[180px_1fr]">
        <Field label="Oldest build allowed">
          <input inputMode="numeric" className={inputClass} value={min} onChange={(e) => setMin(e.target.value.replace(/\D/g, ""))} />
        </Field>
        <Field label="Where to get the new one (https://…, optional)">
          <input className={inputClass} placeholder="https://play.google.com/store/apps/details?id=…" value={url} onChange={(e) => setUrl(e.target.value.trim())} />
        </Field>
      </div>
      <div className="mt-4 flex justify-end">
        <Button variant="primary" disabled={!ok} onClick={save}>Save</Button>
      </div>
    </Card>
  );
}

function Banner({ config, onSaved }: { config: AppConfig; onSaved: () => void }) {
  const act = useAction();
  const b = config.banner;
  const [tone, setTone] = useState<"info" | "warn">(b?.tone ?? "info");
  const [bn, setBn] = useState<Line>(b?.bn ?? { title: "", body: "" });
  const [en, setEn] = useState<Line>(b?.en ?? { title: "", body: "" });
  const live = b?.on ?? false;
  const fits = (l: Line) => l.title.length <= 80 && l.body.length <= 300;
  const ready = bn.title.trim() !== "" && en.title.trim() !== "" && fits(bn) && fits(en);
  const put = (on: boolean) =>
    act(null, () => adminCall("config", { banner: { on, tone, bn, en } }), on ? "The banner is up in the app." : "The banner is down.").then(
      (ok) => ok && onSaved(),
    );
  return (
    <Card
      title={<span className="flex items-center gap-2">Banner in the app {live ? <Badge tone="good">Showing</Badge> : <Badge>Off</Badge>}</span>}
      actions={live && <Button size="sm" onClick={() => put(false)}>Take it down</Button>}
    >
      <p className="text-sm text-muted">A notice across the top of the app, without a push notification. Each person can close it; putting it up again shows it again.</p>
      <div className="mt-4 flex gap-1.5">
        {(["info", "warn"] as const).map((t) => (
          <button key={t} type="button" onClick={() => setTone(t)}
            className={cx("h-9 rounded-lg px-3 text-[13px] font-medium", tone === t ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink")}>
            {t === "info" ? "News" : "Warning"}
          </button>
        ))}
      </div>
      <div className="mt-4 grid gap-6 md:grid-cols-2">
        {([["বাংলা", bn, setBn, "bn"], ["English", en, setEn, "en"]] as const).map(([label, line, set, lang]) => (
          <div key={lang} className="flex min-w-0 flex-col gap-3">
            <div className="text-sm font-semibold text-ink-strong">{label}</div>
            <Field label="Title" count={line.title.length} max={80}>
              <input lang={lang} className={inputClass} value={line.title} onChange={(e) => set({ ...line, title: e.target.value })} />
            </Field>
            <Field label="Text (optional)" count={line.body.length} max={300}>
              <textarea lang={lang} className={cx(inputClass, "h-20 resize-y py-2.5")} value={line.body} onChange={(e) => set({ ...line, body: e.target.value })} />
            </Field>
            <div className={cx("rounded-xl border px-4 py-3", tone === "warn" ? "border-warn/40 bg-warn-soft" : "border-line bg-sunken")}>
              <div className="text-sm font-semibold text-ink-strong">{line.title.trim() || label}</div>
              {line.body.trim() && <div className="mt-0.5 text-sm break-words text-ink">{line.body}</div>}
            </div>
          </div>
        ))}
      </div>
      <div className="mt-4 flex justify-end">
        <Button variant="primary" disabled={!ready} onClick={() => put(true)}>{live ? "Put up the new one" : "Put it up"}</Button>
      </div>
    </Card>
  );
}

// As the rules name them (firestore.rules, featureOn).
const SWITCHES = [
  { id: "globalChat", label: "Global chat", hint: "Messages in Global" },
  { id: "communityChats", label: "Community chats", hint: "Messages in every community's chat" },
  { id: "posting", label: "Posting", hint: "New posts and questions, in Global and communities" },
  { id: "comments", label: "Comments", hint: "New comments on posts" },
  { id: "privateChats", label: "Private chats", hint: "New messages between two people" },
] as const;

function Switches({ off, onSaved }: { off: Record<string, boolean>; onSaved: () => void }) {
  const act = useAction();
  const flip = (id: string, label: string, turnOff: boolean) =>
    act(
      turnOff
        ? { title: `Turn off ${label.toLowerCase()}?`, body: "Nobody can send new ones until you turn it on again; the app tells them the admins have paused it. Everything already there stays readable.", action: "Turn off", danger: true }
        : null,
      () => adminCall("switches", { off: { [id]: turnOff } }),
      turnOff ? `${label} is off.` : `${label} is on again.`,
    ).then((ok) => ok && onSaved());
  const anyOff = SWITCHES.some((s) => off[s.id]);
  return (
    <Card title={<span className="flex items-center gap-2">Switches {anyOff ? <Badge tone="warn">Something is off</Badge> : <Badge tone="good">All on</Badge>}</span>}>
      <p className="text-sm text-muted">For a spam wave or a problem being fixed: stop new messages, posts or comments for a while. The rules enforce it, whatever app version people have.</p>
      <ul className="mt-4 divide-y divide-line-soft">
        {SWITCHES.map((sw) => {
          const on = !off[sw.id];
          return (
            <li key={sw.id} className="flex items-center justify-between gap-4 py-3">
              <span className="min-w-0">
                <span className="block text-sm font-medium text-ink-strong">{sw.label}</span>
                <span className="block text-xs text-muted">{sw.hint}</span>
              </span>
              <Switch on={on} label={sw.label} onChange={(next) => flip(sw.id, sw.label, !next)} />
            </li>
          );
        })}
      </ul>
    </Card>
  );
}

function ReportedPosts({ at, onSaved }: { at: number; onSaved: () => void }) {
  const act = useAction();
  const pick = (n: number) =>
    act(null, () => adminCall("autoHide", { at: n }), n ? `Posts now leave the feeds after ${n} reports.` : "Reports no longer hide posts.").then(
      (ok) => ok && onSaved(),
    );
  return (
    <Card title="Reported posts">
      <p className="text-sm text-muted">
        A post reported by this many different people leaves the feeds until an admin looks — Show again, or delete it, from Reports or the feed. Checked every quarter hour.
      </p>
      <div className="mt-4 flex flex-wrap gap-1.5">
        {[0, 2, 3, 5, 10].map((n) => (
          <button key={n} type="button" onClick={() => n !== at && pick(n)}
            className={cx("h-9 rounded-lg px-3 text-[13px] font-medium", at === n ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink")}>
            {n === 0 ? "Never" : `${n} people`}
          </button>
        ))}
      </div>
    </Card>
  );
}

function Pinned({ post, onSaved }: { post: PostDoc | null; onSaved: () => void }) {
  const act = useAction();
  return (
    <Card title="Pinned in Global" actions={<Link href="/feed/" className="text-sm text-muted hover:text-ink">Pick one in the feed →</Link>}>
      {post ? (
        <div className="flex items-start gap-4">
          <div className="min-w-0 flex-1">
            <div className="text-xs text-muted">@{post.authorUsername} · posted {timeAgo(post.postedAt)}</div>
            <p className="mt-1 line-clamp-3 text-sm break-words text-ink">{post.lesson}</p>
          </div>
          <Button size="sm" onClick={() => act(null, () => adminCall("pin", { postId: "" }), "Unpinned.").then((ok) => ok && onSaved())}>Unpin</Button>
        </div>
      ) : (
        <p className="text-sm text-muted">Nothing pinned. In the feed, “Pin to Global” on a post in Global puts it above the rest.</p>
      )}
    </Card>
  );
}

function SettingsPage() {
  const { data, error, loading, reload } = useLoad(load);
  return (
    <>
      <PageHeader title="App settings" subtitle="What every phone follows as the app runs. Changes reach phones within seconds." />
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : data ? (
        // Keyed by when it was saved, so each form starts from what is live.
        <div key={String(data.config.updatedAt ?? "")} className="flex flex-col gap-6">
          <Maintenance config={data.config} onSaved={reload} />
          <Banner config={data.config} onSaved={reload} />
          <ForceUpdate config={data.config} onSaved={reload} />
          <Switches off={data.off} onSaved={reload} />
          <ReportedPosts at={data.autoHideAt} onSaved={reload} />
          <Pinned post={data.pinned} onSaved={reload} />
        </div>
      ) : null}
    </>
  );
}

export default function Page() {
  const { can } = useSession();
  return can("config") ? (
    <SettingsPage />
  ) : (
    <>
      <PageHeader title="App settings" />
      <AdminsOnly />
    </>
  );
}
