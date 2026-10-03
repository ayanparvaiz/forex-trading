"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { Button, cx } from "./ui";

type Ask = { title: string; body?: React.ReactNode; action: string; danger?: boolean };
type Toast = { id: number; text: string; tone: "good" | "bad" };

type Feedback = {
  confirm: (ask: Ask) => Promise<boolean>;
  toast: (text: string, tone?: Toast["tone"]) => void;
};

const Ctx = createContext<Feedback | null>(null);

/** "Are you sure?" before anything that cannot be undone, and a line after. */
export function FeedbackProvider({ children }: { children: React.ReactNode }) {
  const [ask, setAsk] = useState<(Ask & { answer: (yes: boolean) => void }) | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const next = useRef(1);

  const confirm = useCallback(
    (a: Ask) => new Promise<boolean>((resolve) => setAsk({ ...a, answer: resolve })),
    [],
  );
  const toast = useCallback((text: string, tone: Toast["tone"] = "good") => {
    const id = next.current++;
    setToasts((t) => [...t, { id, text, tone }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3800);
  }, []);

  const close = (yes: boolean) => {
    ask?.answer(yes);
    setAsk(null);
  };

  useEffect(() => {
    if (!ask) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && close(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  return (
    <Ctx.Provider value={{ confirm, toast }}>
      {children}
      {ask && (
        <div className="fixed inset-0 z-50 grid place-items-center bg-ink-strong/30 p-4" onClick={() => close(false)}>
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="confirm-title"
            className="w-full max-w-md rounded-2xl border border-line bg-surface p-6 shadow-[var(--shadow-pop)]"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 id="confirm-title" className="text-lg font-semibold text-ink-strong">{ask.title}</h2>
            {ask.body && <div className="mt-2 text-sm leading-relaxed text-muted">{ask.body}</div>}
            <div className="mt-6 flex justify-end gap-2">
              <Button onClick={() => close(false)} autoFocus>Cancel</Button>
              <Button variant={ask.danger ? "danger" : "primary"} onClick={() => close(true)}>
                {ask.action}
              </Button>
            </div>
          </div>
        </div>
      )}
      <div className="pointer-events-none fixed right-4 bottom-4 z-50 flex w-[min(360px,calc(100vw-2rem))] flex-col gap-2" aria-live="polite">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={cx(
              "pointer-events-auto rounded-xl border px-4 py-3 text-sm shadow-[var(--shadow-pop)]",
              t.tone === "good" ? "border-line bg-primary text-white" : "border-bad/25 bg-bad-soft text-bad",
            )}
          >
            {t.text}
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}

export function useFeedback() {
  const v = useContext(Ctx);
  if (!v) throw new Error("useFeedback outside <FeedbackProvider>");
  return v;
}

/**
 * Runs [work] with a confirm first, a toast after, and the error shown when
 * it fails. Returns whether it was done.
 */
export function useAction() {
  const { confirm, toast } = useFeedback();
  return useCallback(
    async (ask: Ask | null, work: () => Promise<unknown>, done: string) => {
      if (ask && !(await confirm(ask))) return false;
      try {
        await work();
        toast(done);
        return true;
      } catch (e) {
        toast(e instanceof Error ? e.message : "That did not work.", "bad");
        return false;
      }
    },
    [confirm, toast],
  );
}
