/** What someone is in the panel, as the worker decides it (worker/src/admin.js, roleOf). */
export type Role = "owner" | "admin" | "moderator";

/** What a moderator may do; everything else is for admins and owners. */
const MODERATOR = new Set(["deletePost", "deleteComment", "removeMessage", "resolveReport", "warn", "resetProfile", "ban"]);

export const MODERATOR_BAN_DAYS = [1, 3, 7];

export function can(role: Role | null, action: string): boolean {
  if (!role) return false;
  return role !== "moderator" || MODERATOR.has(action);
}

export const ROLE_LABEL: Record<Role, string> = { owner: "Owner", admin: "Admin", moderator: "Moderator" };

/** An admins/{uid} entry, read as a role. */
export function roleFrom(entry: { addedBy?: string; role?: string } | undefined): Role | null {
  if (!entry) return null;
  if (!entry.addedBy) return "owner";
  return entry.role === "moderator" ? "moderator" : "admin";
}
