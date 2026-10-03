"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { FeedbackProvider } from "@/components/feedback";
import { Shell } from "@/components/shell";
import { Button, Loading } from "@/components/ui";
import { useSession } from "@/lib/session";

/** Every page but sign-in: for listed admins only. */
export default function PanelLayout({ children }: LayoutProps<"/">) {
  const { access, user, signOut } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (access === "signed-out") router.replace("/login/");
  }, [access, router]);

  if (access === "checking" || access === "signed-out") {
    return (
      <div className="grid min-h-dvh place-items-center">
        <Loading label="Checking your access…" />
      </div>
    );
  }
  if (access === "not-admin") {
    return (
      <div className="grid min-h-dvh place-items-center p-4">
        <div className="w-full max-w-sm rounded-2xl border border-line bg-surface p-7 text-center shadow-[var(--shadow-card)]">
          <h1 className="text-lg font-semibold text-ink-strong">Not an admin</h1>
          <p className="mt-2 text-sm text-muted">
            @{user?.email?.split("@")[0]} can use the app, but not this panel. Ask an admin to add
            you with <code className="rounded bg-sunken px-1 py-0.5 text-[13px]">tool/make_admin.py</code>.
          </p>
          <Button className="mt-5 w-full" onClick={signOut}>Sign in as someone else</Button>
        </div>
      </div>
    );
  }
  return (
    <FeedbackProvider>
      <Shell>{children}</Shell>
    </FeedbackProvider>
  );
}
