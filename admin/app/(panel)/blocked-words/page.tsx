"use client";

import { doc, getDoc } from "firebase/firestore";
import { useState } from "react";
import { useFeedback } from "@/components/feedback";
import { Button, Card, ErrorNote, Loading, PageHeader, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { db } from "@/lib/firebase";
import { useLoad } from "@/lib/use-load";

// As the worker takes them (worker/src/admin.js, blockedWords).
const MAX = 100;

// What scammers in forex groups post most. Offered, never added unasked.
const SUGGESTED = ["t.me/", "telegram", "wa.me/", "whatsapp group", "vip signal", "signal group", "account management", "guaranteed profit", "100% profit", "টেলিগ্রাম", "ভিআইপি", "সিগন্যাল গ্রুপ", "নিশ্চিত লাভ", "অ্যাকাউন্ট ম্যানেজমেন্ট"];

const tidy = (w: string) => w.trim().toLowerCase().replace(/\s+/g, " ");

async function load() {
  const snap = await getDoc(doc(db, "config", "moderation"));
  return ((snap.data()?.words as string[] | undefined) ?? []).slice();
}

function Editor({ saved, onSaved }: { saved: string[]; onSaved: () => void }) {
  const { toast } = useFeedback();
  const [words, setWords] = useState(saved);
  const [typed, setTyped] = useState("");
  const [busy, setBusy] = useState(false);
  const changed = words.join("\n") !== saved.join("\n");

  const add = (raw: string) => {
    const fresh = raw.split(/[,\n]/).map(tidy).filter((w) => w.length >= 2 && w.length <= 40 && !words.includes(w));
    if (fresh.length) setWords((ws) => [...ws, ...new Set(fresh)].slice(0, MAX));
    setTyped("");
  };
  const save = async () => {
    setBusy(true);
    try {
      await adminCall("blockedWords", { words });
      toast(words.length ? `${words.length} blocked word${words.length === 1 ? "" : "s"} saved. They apply now.` : "Nothing is blocked now.");
      onSaved();
    } catch (e) {
      toast(e instanceof Error ? e.message : "That did not work.", "bad");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
      <Card title={`Blocked · ${words.length}/${MAX}`} actions={changed && <Button variant="primary" size="sm" loading={busy} onClick={save}>Save</Button>}>
        <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); add(typed); }}>
          <input className={inputClass} placeholder="A word, phrase or link — commas for several" value={typed} onChange={(e) => setTyped(e.target.value)} />
          <Button type="submit" disabled={tidy(typed).length < 2}>Add</Button>
        </form>
        {words.length === 0 ? (
          <p className="mt-6 text-sm text-muted">Nothing is blocked. Add words above, or from the suggestions.</p>
        ) : (
          <ul className="mt-4 flex flex-wrap gap-2">
            {words.map((w) => (
              <li key={w} className="flex items-center gap-1 rounded-lg bg-sunken py-1 pr-1 pl-3 text-sm text-ink">
                <span lang="bn">{w}</span>
                <button type="button" aria-label={`Unblock ${w}`} onClick={() => setWords((ws) => ws.filter((x) => x !== w))}
                  className="grid size-6 place-items-center rounded-md text-muted hover:bg-line hover:text-ink">×</button>
              </li>
            ))}
          </ul>
        )}
        {changed && (
          <div className="mt-6 flex items-center justify-between gap-3 border-t border-line-soft pt-4">
            <span className="text-xs text-warn">Not saved yet.</span>
            <span className="flex gap-2">
              <Button variant="ghost" onClick={() => setWords(saved)}>Undo</Button>
              <Button variant="primary" loading={busy} onClick={save}>Save</Button>
            </span>
          </div>
        )}
      </Card>
      <div className="flex flex-col gap-6">
        <Card title="How it works">
          <ul className="list-disc space-y-2 pl-4 text-sm leading-relaxed text-muted">
            <li>A post, comment, or message in Global or a community chat with any of these can&apos;t be sent. The app says why.</li>
            <li>Capital letters don&apos;t matter, and a word inside a longer one counts: “signal” blocks “signals”.</li>
            <li>Private chats between two people aren&apos;t checked.</li>
            <li>What was posted before stays; the feed and chat rooms are where to remove it.</li>
          </ul>
        </Card>
        <Card title="Suggestions">
          <div className="flex flex-wrap gap-1.5">
            {SUGGESTED.filter((w) => !words.includes(w)).map((w) => (
              <button key={w} type="button" onClick={() => add(w)} lang="bn"
                className={cx("rounded-lg px-2.5 py-1 text-[13px] text-muted ring-1 ring-line hover:bg-sunken hover:text-ink")}>
                + {w}
              </button>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}

export default function BlockedWordsPage() {
  const { data, error, loading, reload } = useLoad(load);
  return (
    <>
      <PageHeader title="Blocked words" subtitle="Words and links nobody can post — scam groups, paid signals, abuse." />
      <ErrorNote error={error} />
      {loading && !data ? <Loading /> : data ? <Editor key={data.join("\n")} saved={data} onSaved={reload} /> : null}
    </>
  );
}
