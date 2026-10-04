"use client";

import { useState } from "react";
import { Dialog, Field } from "@/components/dialog";
import { useFeedback } from "@/components/feedback";
import { Button, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import type { CommunityDoc } from "@/lib/types";

/** A new event for a community, in its admin's name, as the app makes them. */
export function EventDialog({ c, onClose, onDone }: { c: CommunityDoc; onClose: () => void; onDone: () => void }) {
  const { toast } = useFeedback();
  const [busy, setBusy] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [at, setAt] = useState("");
  const [announce, setAnnounce] = useState(true);
  const ok = title.trim().length >= 3 && title.length <= 80 && description.length <= 300 && at !== "";

  const save = async () => {
    setBusy(true);
    try {
      const r = await adminCall<{ phones: number }>("event", {
        communityId: c.id,
        op: "create",
        title: title.trim(),
        description: description.trim(),
        startsAt: new Date(at).toISOString(),
        announce,
      });
      toast(announce ? `Event planned; ${r.phones} member phone${r.phones === 1 ? "" : "s"} told.` : "Event planned.");
      onDone();
    } catch (e) {
      toast(e instanceof Error ? e.message : "That did not work.", "bad");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog
      title={`New event in ${c.name}`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={busy} disabled={!ok} onClick={save}>Plan it</Button>
        </>
      }
    >
      <p>It shows in the community as from its admin. Members who say they&apos;re going are reminded shortly before it starts.</p>
      <div className="mt-4 flex flex-col gap-4">
        <Field label="Title" count={title.length} max={80}>
          <input className={inputClass} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Weekly trade review" />
        </Field>
        <Field label="What it is (optional)" count={description.length} max={300}>
          <textarea className={cx(inputClass, "h-20 resize-y py-2.5")} value={description} onChange={(e) => setDescription(e.target.value)} />
        </Field>
        <Field label="When (your time)">
          <input type="datetime-local" className={inputClass} value={at} onChange={(e) => setAt(e.target.value)} />
        </Field>
        <label className="flex items-center gap-3 text-ink">
          <input type="checkbox" className="size-4 accent-primary" checked={announce} onChange={(e) => setAnnounce(e.target.checked)} />
          Tell the members now
        </label>
      </div>
    </Dialog>
  );
}
