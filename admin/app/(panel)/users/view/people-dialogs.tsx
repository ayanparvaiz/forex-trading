"use client";

import { useState } from "react";
import { Dialog, Field } from "@/components/dialog";
import { useFeedback } from "@/components/feedback";
import { Button, cx, inputClass } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { MODERATOR_BAN_DAYS } from "@/lib/roles";
import { useSession } from "@/lib/session";
import type { UserDoc } from "@/lib/types";

type Props = { user: UserDoc; onClose: () => void; onDone: () => void };

function useWork() {
  const { toast } = useFeedback();
  const [busy, setBusy] = useState(false);
  const run = async <T,>(work: () => Promise<T>): Promise<T | null> => {
    setBusy(true);
    try {
      return await work();
    } catch (e) {
      toast(e instanceof Error ? e.message : "That did not work.", "bad");
      return null;
    } finally {
      setBusy(false);
    }
  };
  return { busy, run, toast };
}

const DURATIONS = [
  { days: 1, label: "1 day" },
  { days: 3, label: "3 days" },
  { days: 7, label: "7 days" },
  { days: 30, label: "30 days" },
  { days: 0, label: "Until lifted" },
];

export function BanDialog({ user, onClose, onDone }: Props) {
  const { busy, run, toast } = useWork();
  const [days, setDays] = useState(7);
  const [reason, setReason] = useState("");
  const [clean, setClean] = useState(false);
  const { can, role } = useSession();
  // A moderator's bans end within a week.
  const durations = role === "moderator" ? DURATIONS.filter((d) => MODERATOR_BAN_DAYS.includes(d.days)) : DURATIONS;
  const submit = async () => {
    const done = await run(async () => {
      await adminCall("ban", { uid: user.id, banned: true, ...(days ? { days } : {}), ...(reason.trim() ? { reason: reason.trim() } : {}) });
      if (clean) await adminCall("purge", { uid: user.id });
      return true;
    });
    if (!done) return;
    const banned = days ? `@${user.username} is banned for ${days} day${days === 1 ? "" : "s"}` : `@${user.username} is banned`;
    toast(clean ? `${banned}, and everything they posted is gone.` : `${banned}.`);
    onDone();
  };
  return (
    <Dialog
      title={`Ban @${user.username}`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="danger" loading={busy} disabled={reason.length > 200} onClick={submit}>Ban</Button>
        </>
      }
    >
      <p>
        They are signed out on every phone and can&apos;t sign in until the ban ends.{" "}
        {clean ? "Everything they posted goes too." : "Their posts and messages stay."}
      </p>
      <div className="mt-4 flex flex-col gap-4">
        <div>
          <div className="mb-1.5 text-xs font-medium text-muted">For how long</div>
          <div className="flex flex-wrap gap-1.5">
            {durations.map((d) => (
              <button
                key={d.days}
                type="button"
                onClick={() => setDays(d.days)}
                className={cx(
                  "h-9 rounded-lg px-3 text-[13px] font-medium",
                  days === d.days ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink",
                )}
              >
                {d.label}
              </button>
            ))}
          </div>
        </div>
        <Field label="Why (only admins see this)" count={reason.length} max={200}>
          <textarea className={cx(inputClass, "h-20 resize-y py-2.5")} value={reason} onChange={(e) => setReason(e.target.value)} />
        </Field>
        {can("purge") && (
        <label className="flex items-start gap-3 rounded-xl bg-sunken p-3 text-ink">
          <input type="checkbox" className="mt-0.5 size-4 accent-primary" checked={clean} onChange={(e) => setClean(e.target.checked)} />
          <span>
            <span className="block font-medium">Also remove everything they posted</span>
            <span className="block text-xs text-muted">Their posts, comments, and messages in Global and community chats — for spam. Private chats stay. This can&apos;t be undone.</span>
          </span>
        </label>
        )}
      </div>
    </Dialog>
  );
}

// Easy to read out over a call: no 0/o, 1/l/i.
const LETTERS = "abcdefghjkmnpqrstuvwxyz23456789";
function newPassword() {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  const chars = [...bytes].map((b) => LETTERS[b % LETTERS.length]).join("");
  return `fx-${chars.slice(0, 4)}-${chars.slice(4)}`;
}

export function PasswordDialog({ user, onClose }: Props) {
  const { busy, run } = useWork();
  const [password, setPassword] = useState(newPassword);
  const [set, setSet] = useState(false);
  const [copied, setCopied] = useState(false);
  const submit = async () => {
    // Stays open on success: the password is shown once, here.
    if (await run(() => adminCall("setPassword", { uid: user.id, password }))) setSet(true);
  };
  const copy = async () => {
    await navigator.clipboard.writeText(password).catch(() => {});
    setCopied(true);
  };
  if (set) {
    return (
      <Dialog title="Password changed" onClose={onClose} footer={<Button variant="primary" onClick={onClose}>Done</Button>}>
        <p>Tell @{user.username} this password, then ask them to change it in the app (Settings → Change password).</p>
        <div className="mt-4 flex items-center gap-2 rounded-xl bg-sunken px-4 py-3">
          <code className="flex-1 font-mono text-base text-ink-strong">{password}</code>
          <Button size="sm" onClick={copy}>{copied ? "Copied" : "Copy"}</Button>
        </div>
        <p className="mt-3 text-xs">It is shown only now. It isn&apos;t kept anywhere, not even in the activity log.</p>
      </Dialog>
    );
  }
  return (
    <Dialog
      title={`New password for @${user.username}`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={busy} disabled={password.length < 6 || password.length > 64} onClick={submit}>Set password</Button>
        </>
      }
    >
      <p>For someone who forgot theirs — the app has no other way back in. Their old password stops working and they are signed out everywhere.</p>
      <p className="mt-2 font-medium text-ink">Make sure it&apos;s really them asking, for example by a message from the phone they use.</p>
      <div className="mt-4 flex gap-2">
        <input className={cx(inputClass, "font-mono")} value={password} onChange={(e) => setPassword(e.target.value)} aria-label="New password" />
        <Button onClick={() => setPassword(newPassword())}>New one</Button>
      </div>
      {password.length < 6 && <p className="mt-1.5 text-xs text-bad">At least 6 characters.</p>}
    </Dialog>
  );
}

const WARNINGS = [
  "সিগন্যাল, ভিআইপি গ্রুপ বা টাকার লিংক দেওয়া এখানে নিষেধ। আবার দিলে অ্যাকাউন্ট বন্ধ হবে।",
  "সবার সাথে সম্মান রেখে কথা বলুন। গালাগালি আবার হলে অ্যাকাউন্ট বন্ধ হবে।",
  "একই কথা বারবার পোস্ট করবেন না। স্প্যাম আবার হলে অ্যাকাউন্ট বন্ধ হবে।",
];

export function WarnDialog({ user, onClose, onDone }: Props) {
  const { busy, run, toast } = useWork();
  const [message, setMessage] = useState("");
  const submit = async () => {
    const r = await run(() => adminCall<{ phones: number }>("warn", { uid: user.id, message: message.trim() }));
    if (!r) return;
    toast(
      r.phones > 0
        ? `Warning sent to @${user.username}'s phone${r.phones === 1 ? "" : "s"}.`
        : `@${user.username} has notifications off, so no phone got it. It's in the activity log.`,
      r.phones > 0 ? "good" : "bad",
    );
    onDone();
  };
  return (
    <Dialog
      title={`Warn @${user.username}`}
      wide
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={busy} disabled={!message.trim() || message.length > 300} onClick={submit}>Send warning</Button>
        </>
      }
    >
      <p>A notification to their phones only, titled “A warning from the admins” in their language. Nobody else sees it.</p>
      <div className="mt-4 flex flex-col gap-2">
        {WARNINGS.map((w) => (
          <button key={w} type="button" onClick={() => setMessage(w)} className="rounded-lg bg-sunken px-3 py-2 text-left text-[13px] text-ink hover:bg-line-soft">
            {w}
          </button>
        ))}
      </div>
      <div className="mt-4">
        <Field label="Message" count={message.length} max={300}>
          <textarea className={cx(inputClass, "h-24 resize-y py-2.5")} lang="bn" value={message} onChange={(e) => setMessage(e.target.value)} />
        </Field>
      </div>
    </Dialog>
  );
}

export function ResetDialog({ user, onClose, onDone }: Props) {
  const { busy, run, toast } = useWork();
  const [name, setName] = useState(true);
  const [avatar, setAvatar] = useState(false);
  const submit = async () => {
    if (!(await run(() => adminCall("resetProfile", { uid: user.id, name, avatar })))) return;
    toast(`@${user.username}'s ${name && avatar ? "name and picture are" : name ? "name is" : "picture is"} back to plain.`);
    onDone();
  };
  const box = "size-4 accent-primary";
  return (
    <Dialog
      title={`Fix @${user.username}'s profile`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={busy} disabled={!name && !avatar} onClick={submit}>Reset</Button>
        </>
      }
    >
      <p>For a name or picture nobody should have to see.</p>
      <div className="mt-4 flex flex-col gap-3 text-ink">
        <label className="flex items-center gap-3"><input type="checkbox" className={box} checked={name} onChange={(e) => setName(e.target.checked)} /> Name → “{user.username}” (now “{user.displayName}”)</label>
        <label className="flex items-center gap-3"><input type="checkbox" className={box} checked={avatar} onChange={(e) => setAvatar(e.target.checked)} /> Picture → the first one</label>
      </div>
      <p className="mt-4 text-xs">Comments and messages already written keep the old name. They can change it again, so a warning helps.</p>
    </Dialog>
  );
}
