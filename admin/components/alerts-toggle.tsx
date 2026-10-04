"use client";

import { doc, getDoc } from "firebase/firestore";
import { useState } from "react";
import { adminCall } from "@/lib/admin-api";
import { db } from "@/lib/firebase";
import { useSession } from "@/lib/session";
import { useLoad } from "@/lib/use-load";
import { useFeedback } from "./feedback";
import { cx } from "./ui";

/**
 * Whether new reports reach this admin's phone (worker/src/admin-cron.js) —
 * through the app, signed in as them, with notifications on.
 */
export function AlertsToggle() {
  const { user } = useSession();
  const { toast } = useFeedback();
  const uid = user?.uid ?? "";
  const { data } = useLoad(async () => (await getDoc(doc(db, "admins", uid))).data()?.alerts !== false, uid);
  const [mine, setMine] = useState<boolean | null>(null);
  const on = mine ?? data ?? true;
  const flip = async () => {
    try {
      await adminCall("alerts", { on: !on });
      setMine(!on);
      toast(!on ? "New reports will reach your phone." : "No more report alerts on your phone.");
    } catch (e) {
      toast(e instanceof Error ? e.message : "That did not work.", "bad");
    }
  };
  return (
    <button type="button" role="switch" aria-checked={on} onClick={flip}
      title="Through the app on your phone, signed in as you, with notifications on"
      className="flex h-8 items-center gap-2 rounded-lg px-2.5 text-[13px] text-muted ring-1 ring-line hover:text-ink">
      <span className={cx("relative h-4 w-7 rounded-full transition-colors", on ? "bg-primary" : "bg-line")}>
        <span className={cx("absolute top-0.5 size-3 rounded-full bg-white transition-[left]", on ? "left-3.5" : "left-0.5")} />
      </span>
      Alerts on my phone
    </button>
  );
}
