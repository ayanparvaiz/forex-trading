"use client";

import { useState } from "react";
import { Dialog, Field } from "@/components/dialog";
import { useFeedback } from "@/components/feedback";
import { Button, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import type { CommunityDoc } from "@/lib/types";

const SLOW = [
  { s: 0, label: "Off" },
  { s: 10, label: "10 sec" },
  { s: 30, label: "30 sec" },
  { s: 60, label: "1 min" },
  { s: 300, label: "5 min" },
];

/** What its own admin can change, and its name, which only here can. */
export function EditDialog({ c, onClose, onDone }: { c: CommunityDoc; onClose: () => void; onDone: () => void }) {
  const { toast } = useFeedback();
  const [busy, setBusy] = useState(false);
  const [name, setName] = useState(c.name);
  const [description, setDescription] = useState(c.description ?? "");
  const [rules, setRules] = useState((c.rules ?? []).join("\n"));
  const [slow, setSlow] = useState(c.slowSeconds ?? 0);

  const lines = rules.split("\n").map((r) => r.trim()).filter(Boolean);
  const nameOk = name.trim().length >= 3 && name.trim().length <= 60 && !name.includes("/");
  const ok = nameOk && description.length <= 200 && lines.length <= 5 && lines.every((r) => r.length <= 120);

  const save = async () => {
    const change: Record<string, unknown> = {};
    if (name.trim() !== c.name) change.name = name.trim();
    if (description !== (c.description ?? "")) change.description = description;
    if (lines.join("\n") !== (c.rules ?? []).join("\n")) change.rules = lines;
    if (slow !== (c.slowSeconds ?? 0)) change.slowSeconds = slow;
    if (!Object.keys(change).length) return onClose();
    setBusy(true);
    try {
      await adminCall("community", { communityId: c.id, op: "edit", ...change });
      toast("Saved.");
      onDone();
    } catch (e) {
      toast(e instanceof Error ? e.message : "That did not work.", "bad");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog
      title={`Edit ${c.name}`}
      wide
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={busy} disabled={!ok} onClick={save}>Save</Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Field label="Name" count={name.trim().length} max={60}>
          <input className={inputClass} value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label="About" count={description.length} max={200}>
          <textarea className={cx(inputClass, "h-20 resize-y py-2.5")} value={description} onChange={(e) => setDescription(e.target.value)} />
        </Field>
        <Field label={`Rules — one a line, five at most (${lines.length}/5)`}>
          <textarea className={cx(inputClass, "h-28 resize-y py-2.5")} value={rules} onChange={(e) => setRules(e.target.value)} />
        </Field>
        {lines.some((r) => r.length > 120) && <p className="-mt-2 text-xs text-bad">Each rule can be 120 letters at most.</p>}
        <div>
          <div className="mb-1.5 text-xs font-medium text-muted">Slow mode — time between one member&apos;s messages</div>
          <div className="flex flex-wrap gap-1.5">
            {SLOW.map((o) => (
              <button key={o.s} type="button" onClick={() => setSlow(o.s)}
                className={cx("h-9 rounded-lg px-3 text-[13px] font-medium", slow === o.s ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink")}>
                {o.label}
              </button>
            ))}
          </div>
        </div>
      </div>
    </Dialog>
  );
}
