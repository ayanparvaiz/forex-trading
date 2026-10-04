"use client";

import { collection, getDocs, limit, query, Timestamp, type DocumentData } from "firebase/firestore";
import { useState } from "react";
import { useFeedback } from "@/components/feedback";
import { AdminsOnly, Button, Card, PageHeader } from "@/components/ui";
import { csvDate } from "@/lib/csv";
import { db } from "@/lib/firebase";
import { useSession } from "@/lib/session";

// At most this many from any one collection: a backup, not a way to spend
// the day's free reads.
const CAP = 5000;

/** Timestamps as ISO text, so the file reads back anywhere. */
function plain(v: unknown): unknown {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (Array.isArray(v)) return v.map(plain);
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v as DocumentData).map(([k, x]) => [k, plain(x)]));
  return v;
}

async function read(path: string[]): Promise<Record<string, unknown>> {
  const [first, ...rest] = path;
  const snap = await getDocs(query(collection(db, first, ...rest), limit(CAP)));
  return Object.fromEntries(snap.docs.map((d) => [d.id, plain(d.data())]));
}

const TOP = ["users", "communities", "posts", "reports", "announcements", "scheduled", "adminLog", "admins", "config", "stats", "champions"];

function Backup() {
  const { user } = useSession();
  const { toast } = useFeedback();
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<string[]>([]);

  const run = async () => {
    setBusy(true);
    setProgress([]);
    const note = (line: string) => setProgress((p) => [...p, line]);
    try {
      const out: Record<string, unknown> = {};
      let reads = 0;
      for (const name of TOP) {
        const docs = await read([name]);
        out[name] = docs;
        reads += Object.keys(docs).length;
        note(`${name}: ${Object.keys(docs).length}`);
      }
      // What lives under each community, post and public chat room.
      const under: Record<string, unknown> = {};
      for (const cid of Object.keys(out.communities as object)) {
        for (const sub of ["members", "events"]) {
          const docs = await read(["communities", cid, sub]);
          under[`communities/${cid}/${sub}`] = docs;
          reads += Object.keys(docs).length;
        }
      }
      note("community members and events");
      for (const pid of Object.keys(out.posts as object)) {
        const docs = await read(["posts", pid, "comments"]);
        if (Object.keys(docs).length) under[`posts/${pid}/comments`] = docs;
        reads += Object.keys(docs).length;
      }
      note("comments");
      for (const room of ["global", ...Object.keys(out.communities as object).map((c) => `c_${c}`)]) {
        const docs = await read(["rooms", room, "messages"]);
        under[`rooms/${room}/messages`] = docs;
        reads += Object.keys(docs).length;
      }
      note("Global and community chat messages");

      const file = {
        app: "Forex Social",
        exportedAt: new Date().toISOString(),
        exportedBy: user?.email?.split("@")[0] ?? "",
        leftOut: "Private chats, trade journals, presence and phones' push tokens: not readable by admins, or not worth keeping.",
        collections: out,
        subcollections: under,
      };
      const url = URL.createObjectURL(new Blob([JSON.stringify(file, null, 1)], { type: "application/json" }));
      const a = document.createElement("a");
      a.href = url;
      a.download = `forex-social-backup-${csvDate(new Date()).slice(0, 10)}.json`;
      document.body.append(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      note(`Done — ${reads.toLocaleString("en-US")} documents.`);
      toast("Backup downloaded.");
    } catch (e) {
      toast(e instanceof Error ? e.message : "The backup stopped part-way.", "bad");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
      <Card title="Download everything">
        <p className="text-sm leading-relaxed text-muted">
          One JSON file with accounts, communities with their members and events, posts with their comments, Global and community chat messages, reports, announcements, the activity log, admins, settings and daily numbers.
        </p>
        <p className="mt-3 text-sm leading-relaxed text-muted">
          Left out: private chats and trade journals (admins can&apos;t read them), and phones&apos; push tokens. Each document counts as one read against Firestore&apos;s free 50,000 a day.
        </p>
        <div className="mt-5">
          <Button variant="primary" loading={busy} onClick={run}>Download backup</Button>
        </div>
        {progress.length > 0 && (
          <ul className="mt-5 space-y-1 rounded-xl bg-sunken p-4 font-mono text-xs text-muted">
            {progress.map((p, i) => <li key={i}>{p}</li>)}
          </ul>
        )}
      </Card>
      <Card title="Keep it safe" className="h-fit">
        <ul className="list-disc space-y-2 pl-4 text-sm leading-relaxed text-muted">
          <li>It holds people&apos;s names and what they posted: store it where only you can open it.</li>
          <li>Take one before a big change, and now and then — say, each month.</li>
        </ul>
      </Card>
    </div>
  );
}

export default function Page() {
  const { can } = useSession();
  return (
    <>
      <PageHeader title="Backup" subtitle="Everything in the app the panel can read, in one file on your computer." />
      {can("backup") ? <Backup /> : <AdminsOnly />}
    </>
  );
}
