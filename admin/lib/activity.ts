import { collection, getDocs, limit, query, where } from "firebase/firestore";
import { db } from "./firebase";
import { toDate } from "./format";
import { rows, type When } from "./types";

/** One line of the activity log, as the worker writes it (worker/src/admin.js). */
export type LogEntry = {
  id: string;
  action: string;
  by: string;
  byUsername?: string;
  at?: When;
  uid?: string;
  username?: string;
  postId?: string;
  commentId?: string;
  roomId?: string;
  messageId?: string;
  reportId?: string;
  communityId?: string;
  communityName?: string;
  op?: string;
  status?: string;
  banned?: boolean;
  days?: number;
  reason?: string;
  author?: string;
  snippet?: string;
  title?: string;
  sent?: number;
  reports?: number;
  phones?: number;
  what?: string;
};

const newestFirst = (a: LogEntry, b: LogEntry) => (toDate(b.at)?.getTime() ?? 0) - (toDate(a.at)?.getTime() ?? 0);

export async function recentActivity(n = 300): Promise<LogEntry[]> {
  // Sorted here: an orderBy would need an index nobody else does.
  return rows<LogEntry>(await getDocs(query(collection(db, "adminLog"), limit(n)))).sort(newestFirst);
}

/** What was done to one account. */
export async function activityAbout(uid: string): Promise<LogEntry[]> {
  return rows<LogEntry>(await getDocs(query(collection(db, "adminLog"), where("uid", "==", uid), limit(100)))).sort(newestFirst);
}

const who = (u?: string) => (u ? `@${u}` : "someone");
const place = (e: LogEntry) => (e.roomId === "global" ? "Global" : (e.communityName ?? "a community chat"));

/** The log line as a sentence, after the admin's name. */
export function sentence(e: LogEntry): string {
  switch (e.action) {
    case "ban":
      return e.banned
        ? `banned ${who(e.username)}${e.days ? ` for ${e.days} day${e.days === 1 ? "" : "s"}` : ""}`
        : `lifted the ban on ${who(e.username)}`;
    case "liftBan":
      return `${who(e.username)}'s ban ran out`;
    case "deleteUser":
      return `deleted ${who(e.username)}'s account`;
    case "deletePost":
      return `deleted a post by ${who(e.author)}`;
    case "deleteComment":
      return `deleted a comment by ${who(e.author)}`;
    case "removeMessage":
      return `removed a message by ${who(e.author)} in ${place(e)}`;
    case "resolveReport":
      return e.status === "open"
        ? `opened a report about ${who(e.author)} again`
        : `${e.status} a report about ${who(e.author)}${e.reason ? ` (${e.reason})` : ""}`;
    case "community":
      switch (e.op) {
        case "lock":
          return `locked ${e.communityName ?? "a community"}`;
        case "unlock":
          return `unlocked ${e.communityName ?? "a community"}`;
        case "delete":
          return `deleted the community ${e.communityName ?? ""}`.trim();
        case "remove":
          return `removed ${who(e.username)} from ${e.communityName ?? "a community"}`;
        case "edit":
          return `edited ${e.communityName ?? "a community"}`;
        case "transfer":
          return `made ${who(e.username)} the admin of ${e.communityName ?? "a community"}`;
        default:
          return `changed ${e.communityName ?? "a community"}`;
      }
    case "broadcast":
      return `announced “${e.title ?? ""}”${e.communityName ? ` to ${e.communityName}` : " to everyone"}`;
    case "setPassword":
      return `set a new password for ${who(e.username)}`;
    case "warn":
      return `warned ${who(e.username)}`;
    case "resetProfile":
      return `reset ${who(e.username)}'s ${e.what ?? "profile"}`;
    case "addAdmin":
      return `made ${who(e.username)} ${e.what === "moderator" ? "a moderator" : "an admin"}`;
    case "autoHide":
      // The worker hiding a post, or an admin setting when it should.
      return e.postId
        ? `took a post by ${who(e.author)} off the feeds: reported by ${e.reports ?? "several"} people`
        : `set ${e.what ?? "when reports hide a post"}`;
    case "unhide":
      return `put a post back on the feeds`;
    case "schedule":
      return `scheduled “${e.title ?? ""}”${e.communityName ? ` for ${e.communityName}` : ""}`;
    case "cancelScheduled":
      return "cancelled a scheduled announcement";
    case "alerts":
      return `turned ${e.what ?? "report alerts"}`;
    case "event":
      return e.op === "delete"
        ? `took down an event in ${e.communityName ?? "a community"}`
        : `planned “${e.title ?? ""}” in ${e.communityName ?? "a community"}`;
    case "purge":
      return `removed everything ${who(e.username)} posted`;
    case "removeAdmin":
      return `took ${who(e.username)}'s admin access away`;
    case "config":
      return `changed the app settings${e.what ? `: ${e.what}` : ""}`;
    case "pin":
      return e.postId ? `pinned a post by ${who(e.author)} to Global` : "unpinned the Global post";
    case "blockedWords":
      return `changed the blocked words${e.what ? `: ${e.what}` : ""}`;
    default:
      return e.action;
  }
}

/** Which filter a log line belongs under. */
export function area(action: string): string {
  if (["ban", "liftBan", "deleteUser", "setPassword", "warn", "resetProfile", "purge"].includes(action)) return "People";
  if (["deletePost", "deleteComment", "removeMessage", "pin", "autoHide", "unhide"].includes(action)) return "Content";
  if (action === "resolveReport") return "Reports";
  if (action === "community" || action === "event") return "Communities";
  if (["broadcast", "schedule", "cancelScheduled"].includes(action)) return "Announcements";
  return "Admins & settings";
}
export const AREAS = ["People", "Content", "Reports", "Communities", "Announcements", "Admins & settings"];
