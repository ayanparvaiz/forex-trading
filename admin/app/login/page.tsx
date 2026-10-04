"use client";

import { FirebaseError } from "firebase/app";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Button, inputClass } from "@/components/ui";
import { useSignedOutIdle } from "@/lib/idle";
import { useSession } from "@/lib/session";

function reason(e: unknown) {
  const code = e instanceof FirebaseError ? e.code : "";
  if (code === "auth/invalid-credential" || code === "auth/wrong-password" || code === "auth/user-not-found")
    return "Wrong username or password.";
  if (code === "auth/user-disabled") return "This account has been banned.";
  if (code === "auth/too-many-requests") return "Too many tries. Wait a minute and try again.";
  if (code === "auth/network-request-failed") return "No connection. Check the internet and try again.";
  return "Could not sign in. Try again.";
}

export default function LoginPage() {
  const { access, signIn } = useSession();
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [idle, forgetIdle] = useSignedOutIdle();

  useEffect(() => {
    if (access === "admin" || access === "not-admin") router.replace("/");
  }, [access, router]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signIn(username, password);
      forgetIdle();
    } catch (err) {
      setError(reason(err));
      setBusy(false);
    }
  }

  return (
    <div className="grid min-h-dvh place-items-center bg-canvas p-4">
      <form onSubmit={submit} className="w-full max-w-sm rounded-2xl border border-line bg-surface p-7 shadow-[var(--shadow-card)]">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/icon.png" alt="" width={44} height={44} className="rounded-xl" />
        <h1 className="mt-5 text-xl font-semibold text-ink-strong">Sign in to the admin panel</h1>
        <p className="mt-1 text-sm text-muted">Use your Forex Social username and password.</p>
        {idle && (
          <p className="mt-4 rounded-lg bg-sunken px-3 py-2 text-sm text-ink">You were signed out after 30 minutes without activity.</p>
        )}
        <label className="mt-6 block text-sm font-medium text-ink" htmlFor="username">Username</label>
        <input id="username" className={`${inputClass} mt-1.5`} autoComplete="username" autoCapitalize="none"
          value={username} onChange={(e) => setUsername(e.target.value)} placeholder="ayan" required />
        <label className="mt-4 block text-sm font-medium text-ink" htmlFor="password">Password</label>
        <input id="password" type="password" className={`${inputClass} mt-1.5`} autoComplete="current-password"
          value={password} onChange={(e) => setPassword(e.target.value)} required />
        {error && <p className="mt-3 text-sm text-bad">{error}</p>}
        <Button type="submit" variant="primary" className="mt-6 w-full" loading={busy}>Sign in</Button>
      </form>
    </div>
  );
}
