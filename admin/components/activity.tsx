import Link from "next/link";
import { sentence, type LogEntry } from "@/lib/activity";
import { dateTime, timeAgo } from "@/lib/format";
import { Empty } from "./ui";

/** Log lines, newest first: who, what, to whom, when. */
export function ActivityList({ entries, empty = "Nothing done yet" }: { entries: LogEntry[]; empty?: string }) {
  if (entries.length === 0) return <Empty title={empty} hint="Every change an admin makes is written here." />;
  return (
    <ul className="divide-y divide-line-soft">
      {entries.map((e) => (
        <li key={e.id} className="flex gap-3 px-5 py-3">
          <div className="min-w-0 flex-1">
            <p className="text-sm break-words text-ink">
              <span className="font-medium text-ink-strong">{e.by === "system" ? "Automatically" : `@${e.byUsername ?? "an admin"}`}</span>{" "}
              {e.uid && e.action !== "deleteUser" ? (
                <Link href={`/users/view/?uid=${e.uid}`} className="hover:underline">{sentence(e)}</Link>
              ) : (
                sentence(e)
              )}
            </p>
            {(e.snippet || e.reason) && e.action !== "resolveReport" && (
              <p className="mt-1 line-clamp-2 text-xs break-words text-muted">
                {e.snippet ? `“${e.snippet}”` : `Reason: ${e.reason}`}
              </p>
            )}
          </div>
          <span className="shrink-0 text-xs text-faint" title={dateTime(e.at)}>{timeAgo(e.at)}</span>
        </li>
      ))}
    </ul>
  );
}
