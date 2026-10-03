"use client";

import { collection, getDocs, limit, query } from "firebase/firestore";
import Link from "next/link";
import { useState } from "react";
import { useAction } from "@/components/feedback";
import { Avatar, Badge, Button, Card, ErrorNote, Loading, PageHeader, Table, cx, inputClass, td } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allUsers } from "@/lib/data";
import { db } from "@/lib/firebase";
import { dateLabel } from "@/lib/format";
import { useSession } from "@/lib/session";
import { rows, type When } from "@/lib/types";
import { useLoad } from "@/lib/use-load";

type AdminDoc = { id: string; username?: string; addedAt?: When; addedBy?: string };

async function load() {
  const [admins, users] = await Promise.all([getDocs(query(collection(db, "admins"), limit(100))), allUsers()]);
  return { admins: rows<AdminDoc>(admins), users: new Map(users.map((u) => [u.id, u])) };
}

export default function AdminsPage() {
  const { user } = useSession();
  const act = useAction();
  const { data, error, loading, reload } = useLoad(load);
  const [username, setUsername] = useState("");

  const name = username.trim().toLowerCase().replace(/^@/, "");
  const add = () =>
    act(
      {
        title: `Make @${name} an admin?`,
        body: "They will see everything in this panel except private chats, and can ban, delete and announce to everyone. Only add someone you trust.",
        action: "Make admin",
      },
      () => adminCall("addAdmin", { username: name }),
      `@${name} is an admin now. They sign in here with their app username and password.`,
    ).then((ok) => {
      if (!ok) return;
      setUsername("");
      reload();
    });

  const remove = (a: AdminDoc, label: string) =>
    act(
      { title: `Take away ${label}'s admin access?`, body: "Their app account stays as it is; only this panel closes to them.", action: "Remove", danger: true },
      () => adminCall("removeAdmin", { uid: a.id }),
      `${label} is no longer an admin.`,
    ).then((ok) => ok && reload());

  return (
    <>
      <PageHeader title="Admins" subtitle="Who can use this panel. Admins sign in with their app username and password." />
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <Card title={data ? `Admins · ${data.admins.length}` : "Admins"} flush>
          <ErrorNote error={error} />
          {loading && !data ? (
            <Loading />
          ) : (
            <Table head={["Admin", "Added", "By", ""]}>
              {(data?.admins ?? []).map((a) => {
                const u = data?.users.get(a.id);
                const label = `@${u?.username ?? a.username ?? "unknown"}`;
                const me = a.id === user?.uid;
                const by = a.addedBy ? data?.users.get(a.addedBy)?.username : undefined;
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
                    <td className={cx(td, "whitespace-nowrap text-muted")}>{dateLabel(a.addedAt)}</td>
                    <td className={cx(td, "text-muted")}>{a.addedBy ? `@${by ?? "an admin"}` : <Badge>Owner</Badge>}</td>
                    <td className={cx(td, "text-right")}>
                      {!me && a.addedBy && <Button size="sm" variant="ghost" onClick={() => remove(a, label)}>Remove</Button>}
                    </td>
                  </tr>
                );
              })}
            </Table>
          )}
        </Card>
        <Card title="Add an admin" className="h-fit">
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
            <Button variant="primary" type="submit" disabled={!/^[a-z0-9_]{3,20}$/.test(name)}>Make admin</Button>
            <p className="text-xs leading-relaxed text-muted">
              An admin can ban, delete and announce to everyone, so add only people you trust. Nobody can remove themselves, and owners — set up by hand with tool/make_admin.py — can be removed only that way.
            </p>
          </form>
        </Card>
      </div>
    </>
  );
}
