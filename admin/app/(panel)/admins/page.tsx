"use client";

import { collection, getDocs, limit, query } from "firebase/firestore";
import Link from "next/link";
import { useState } from "react";
import { useAction } from "@/components/feedback";
import { AdminsOnly, Avatar, Badge, Button, Card, ErrorNote, Loading, PageHeader, Table, cx, inputClass, td } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateLabel } from "@/lib/format";
import { ROLE_LABEL, roleFrom } from "@/lib/roles";
import { useSession } from "@/lib/session";
import { rows, type When } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

type AdminDoc = { id: string; username?: string; addedAt?: When; addedBy?: string; role?: string };

async function load() {
  const [admins, users] = await Promise.all([getDocs(query(collection(db, "admins"), limit(100))), allUsers()]);
  return { admins: rows<AdminDoc>(admins), users: new Map(users.map((u) => [u.id, u])) };
}

const WHAT_THEY_DO = {
  admin: "Everything in this panel except private chats: bans, deleting accounts, communities, announcements, settings, other admins.",
  moderator: "Posts, comments, chat messages and reports: removing them, warning people, fixing a name, and bans of up to a week.",
};

function AdminsPage() {
  const { user } = useSession();
  const act = useAction();
  const { data, error, loading, reload } = useLoad(load);
  const [username, setUsername] = useState("");
  const [role, setRole] = useState<"admin" | "moderator">("moderator");

  const name = username.trim().toLowerCase().replace(/^@/, "");
  const add = () =>
    act(
      {
        title: `Make @${name} ${role === "admin" ? "an admin" : "a moderator"}?`,
        body: `${WHAT_THEY_DO[role]} Only add someone you trust.`,
        action: role === "admin" ? "Make admin" : "Make moderator",
      },
      () => adminCall("addAdmin", { username: name, role }),
      `@${name} is ${role === "admin" ? "an admin" : "a moderator"} now. They sign in here with their app username and password.`,
    ).then((ok) => {
      if (!ok) return;
      setUsername("");
      reload();
    });

  const change = (label: string, to: "admin" | "moderator") =>
    act(
      { title: `Make ${label} ${to === "admin" ? "an admin" : "a moderator"}?`, body: WHAT_THEY_DO[to], action: "Change" },
      () => adminCall("addAdmin", { username: label.replace(/^@/, ""), role: to }),
      `${label} is ${to === "admin" ? "an admin" : "a moderator"} now.`,
    ).then((ok) => ok && reload());

  const remove = (a: AdminDoc, label: string) =>
    act(
      { title: `Take away ${label}'s admin access?`, body: "Their app account stays as it is; only this panel closes to them.", action: "Remove", danger: true },
      () => adminCall("removeAdmin", { uid: a.id }),
      `${label} is no longer an admin.`,
    ).then((ok) => ok && reload());

  return (
    <>
      <PageHeader title="Admins" subtitle="Who can use this panel: owners, admins and moderators. They sign in with their app username and password." />
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <Card title={data ? `People · ${data.admins.length}` : "People"} flush>
          <ErrorNote error={error} />
          {loading && !data ? (
            <Loading />
          ) : (
            <Table head={["Person", "Role", "Added", ""]}>
              {(data?.admins ?? []).map((a) => {
                const u = data?.users.get(a.id);
                const label = `@${u?.username ?? a.username ?? "unknown"}`;
                const me = a.id === user?.uid;
                const by = a.addedBy ? data?.users.get(a.addedBy)?.username : undefined;
                const r = roleFrom(a);
                return (
                  <tr key={a.id}>
                    <td className={td}>
                      <Link href={`/users/view/?uid=${a.id}`} className="flex min-w-[180px] items-center gap-3">
                        <Avatar id={u?.avatarId} size={32} />
                        <span className="min-w-0">
                          <span className="flex items-center gap-2">
                            <span className="truncate font-medium text-ink-strong">{u?.displayName ?? label}</span>
                            {me && <Badge tone="dark">You</Badge>}
                          </span>
                          <span className="block truncate text-xs text-muted">{label}</span>
                        </span>
                      </Link>
                    </td>
                    <td className={td}>{r && <Badge tone={r === "moderator" ? "neutral" : "dark"}>{ROLE_LABEL[r]}</Badge>}</td>
                    <td className={cx(td, "whitespace-nowrap text-muted")}>
                      {dateLabel(a.addedAt)}
                      <span className="block text-xs text-faint">{a.addedBy ? `by @${by ?? "an admin"}` : "by hand"}</span>
                    </td>
                    <td className={cx(td, "text-right")}>
                      {!me && r !== "owner" && (
                        <span className="flex flex-wrap justify-end gap-1">
                          <Button size="sm" variant="ghost" onClick={() => change(label, r === "moderator" ? "admin" : "moderator")}>
                            {r === "moderator" ? "Make admin" : "Make moderator"}
                          </Button>
                          <Button size="sm" variant="ghost" onClick={() => remove(a, label)}>Remove</Button>
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </Table>
          )}
        </Card>
        <Card title="Add someone" className="h-fit">
          <form
            className="flex flex-col gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              if (name) add();
            }}
          >
            <label className="flex flex-col gap-1.5">
              <span className="text-xs font-medium text-muted">Their app username</span>
              <input className={inputClass} placeholder="@username" value={username} onChange={(e) => setUsername(e.target.value)} autoCapitalize="none" spellCheck={false} />
            </label>
            <div className="flex gap-1.5">
              {(["moderator", "admin"] as const).map((r) => (
                <button key={r} type="button" onClick={() => setRole(r)}
                  className={cx("h-9 flex-1 rounded-lg text-[13px] font-medium", role === r ? "bg-primary text-white" : "bg-surface text-muted ring-1 ring-line hover:text-ink")}>
                  {ROLE_LABEL[r]}
                </button>
              ))}
            </div>
            <p className="text-xs leading-relaxed text-muted">{WHAT_THEY_DO[role]}</p>
            <Button variant="primary" type="submit" disabled={!/^[a-z0-9_]{3,20}$/.test(name)}>{role === "admin" ? "Make admin" : "Make moderator"}</Button>
            <p className="text-xs leading-relaxed text-muted">
              Nobody can remove themselves or change their own role, and owners — set up by hand with tool/make_admin.py — are changed only that way.
            </p>
          </form>
        </Card>
      </div>
    </>
  );
}

export default function Page() {
  const { can } = useSession();
  return can("addAdmin") ? (
    <AdminsPage />
  ) : (
    <>
      <PageHeader title="Admins" />
      <AdminsOnly />
    </>
  );
}
