"use client";

import Link from "next/link";
import { Badge, Card, Empty, ErrorNote, Loading, PageHeader, CommunityPicture } from "@/components/ui";
import { allCommunities, allUsers } from "@/lib/data";
import { dateLabel } from "@/lib/format";
import { useLoad } from "@/lib/use-load";

async function load() {
  const [communities, users] = await Promise.all([allCommunities(), allUsers()]);
  return {
    communities: communities.sort((a, b) => (b.memberCount ?? 0) - (a.memberCount ?? 0)),
    users: new Map(users.map((u) => [u.id, u])),
  };
}

export default function CommunitiesPage() {
  const { data, error, loading } = useLoad(load);
  return (
    <>
      <PageHeader title="Communities" subtitle={data ? `${data.communities.length} communities, biggest first` : "Groups of traders, each with a feed and a chat"} />
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : !data?.communities.length ? (
        <Card><Empty title="No communities yet" /></Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {data.communities.map((c) => {
            const admin = data.users.get(c.createdBy);
            return (
              <Link key={c.id} href={`/communities/view/?id=${c.id}`}
                className="flex min-w-0 flex-col gap-4 rounded-[var(--radius-card)] border border-line bg-surface p-5 shadow-[var(--shadow-card)] transition-colors hover:border-faint">
                <div className="flex items-center gap-3">
                  <CommunityPicture id={c.avatarId} name={c.name} size={48} />
                  <div className="min-w-0">
                    <div className="line-clamp-2 font-medium text-ink-strong">{c.name}</div>
                    <div className="text-xs text-muted">Admin @{admin?.username ?? "unknown"}</div>
                  </div>
                </div>
                {c.description && <p className="line-clamp-2 text-sm text-muted">{c.description}</p>}
                <div className="mt-auto flex flex-wrap items-center gap-2 text-sm">
                  <span className="tabular font-medium text-ink">{c.memberCount ?? 0} members</span>
                  {c.locked && <Badge tone="warn">Locked</Badge>}
                  {(c.slowSeconds ?? 0) > 0 && <Badge>Slow mode</Badge>}
                  {(c.titles ?? []).length > 0 && <Badge tone="dark">🏆 ×{c.titles?.length}</Badge>}
                  <span className="ml-auto text-xs text-faint">since {dateLabel(c.createdAt)}</span>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </>
  );
}
