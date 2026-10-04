"use client";

import { collection, doc, getDoc, getDocs, limit, orderBy, query } from "firebase/firestore";
import Link from "next/link";
import { useMemo, useState } from "react";
import { useAction } from "@/components/feedback";
import { Avatar, Badge, Button, Card, cx, Empty, ErrorNote, inputClass, Loading, PageHeader } from "@/components/ui";
import { adminCall } from "@/lib/admin-api";
import { allUsers, communityNames } from "@/lib/data";
import { db } from "@/lib/firebase";
import { rText, timeAgo, toDate } from "@/lib/format";
import { rows, type CommentDoc, type PostDoc } from "@/lib/types";
import { useSession } from "@/lib/session";
import { useLoad } from "@/lib/use-load";

async function load() {
  const [posts, users, communities, config] = await Promise.all([
    getDocs(query(collection(db, "posts"), orderBy("postedAt", "desc"), limit(400))),
    allUsers(),
    communityNames(),
    getDoc(doc(db, "config", "app")),
  ]);
  // When it was read: what counts as still showing is measured from then.
  return {
    posts: rows<PostDoc>(posts),
    users: new Map(users.map((u) => [u.id, u])),
    communities,
    pinned: (config.data()?.pinnedPostId as string | undefined) ?? "",
    at: Date.now(),
  };
}

const KIND = [
  { id: "all", label: "All posts" },
  { id: "trade", label: "Trades" },
  { id: "question", label: "Questions" },
  { id: "rank", label: "Ranks" },
] as const;

function Comments({ post, onChange }: { post: PostDoc; onChange: () => void }) {
  const act = useAction();
  const { data, error, loading, reload } = useLoad(
    async () => rows<CommentDoc>(await getDocs(query(collection(db, "posts", post.id, "comments"), orderBy("createdAt"), limit(200)))),
    post.id,
  );
  const remove = (c: CommentDoc) =>
    act(
      { title: "Delete this comment?", body: `“${c.body.slice(0, 120)}”`, action: "Delete", danger: true },
      () => adminCall("deleteComment", { postId: post.id, commentId: c.id }),
      "Comment deleted.",
    ).then((ok) => {
      if (ok) {
        reload();
        onChange();
      }
    });
  if (loading && !data) return <Loading label="Loading comments…" />;
  if (error) return <ErrorNote error={error} />;
  if (!data?.length) return <p className="px-1 text-sm text-muted">No comments.</p>;
  return (
    <ul className="flex flex-col gap-3">
      {data.map((c) => (
        <li key={c.id} className="flex items-start gap-3">
          <Avatar id={c.authorAvatarId} size={28} />
          <div className="min-w-0 flex-1 rounded-xl bg-sunken px-3.5 py-2.5">
            <div className="flex flex-wrap items-center gap-2 text-xs text-muted">
              <Link href={`/users/view/?uid=${c.authorUid}`} className="font-medium text-ink hover:underline">{c.authorName ?? `@${c.authorUsername}`}</Link>
              <span>{timeAgo(c.createdAt)}</span>
              {post.answerId === c.id && <Badge tone="good">Best answer</Badge>}
              {(c.likedBy?.length ?? 0) > 0 && <span>· {c.likedBy?.length} likes</span>}
            </div>
            <p className="mt-1 text-sm break-words text-ink">{c.body}</p>
          </div>
          <Button size="sm" variant="ghost" onClick={() => remove(c)}>Delete</Button>
        </li>
      ))}
    </ul>
  );
}

export default function FeedPage() {
  const { data, error, loading, reload } = useLoad(load);
  const act = useAction();
  const [where, setWhere] = useState("all");
  const [kind, setKind] = useState<(typeof KIND)[number]["id"]>("all");
  const [liveOnly, setLiveOnly] = useState(true);
  const [open, setOpen] = useState<string | null>(null);

  const list = useMemo(() => {
    if (!data) return [];
    const now = data.at;
    return data.posts
      .filter((p) => where === "all" || p.community === where)
      .filter((p) => kind === "all" || (p.kind ?? "trade") === kind)
      .filter((p) => !liveOnly || (toDate(p.expiresAt)?.getTime() ?? 0) > now);
  }, [data, where, kind, liveOnly]);

  const remove = (p: PostDoc) =>
    act(
      { title: "Delete this post?", body: "It goes for everyone, with its likes, comments and views.", action: "Delete post", danger: true },
      () => adminCall("deletePost", { postId: p.id }),
      "Post deleted.",
    ).then((ok) => ok && reload());

  const { can } = useSession();
  const pin = (p: PostDoc | null) =>
    act(
      p
        ? { title: "Pin this post to Global?", body: "It shows above every other post in Global, for everyone, until you unpin it — and stays even after its 7 days. Only one post is pinned at a time.", action: "Pin" }
        : null,
      () => adminCall("pin", { postId: p?.id ?? "" }),
      p ? "Pinned to the top of Global." : "Unpinned.",
    ).then((ok) => ok && reload());

  return (
    <>
      <PageHeader title="Feed" subtitle="Every post, in Global and in each community. A post in Global can be pinned above the rest." />
      <Card flush className="mb-5">
        <div className="flex flex-col gap-3 p-4 lg:flex-row lg:items-center">
          <select id="feed-where" className={cx(inputClass, "lg:w-72")} value={where} onChange={(e) => setWhere(e.target.value)}>
            <option value="all">Every feed</option>
            <option value="global">Global</option>
            {[...(data?.communities.values() ?? [])].map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <div className="flex flex-wrap gap-1.5">
            {KIND.map((k) => (
              <button key={k.id} onClick={() => setKind(k.id)}
                className={cx("h-9 rounded-lg px-3 text-[13px] font-medium", kind === k.id ? "bg-primary text-white" : "bg-sunken text-muted hover:text-ink")}>
                {k.label}
              </button>
            ))}
          </div>
          <label className="flex items-center gap-2 text-sm text-muted lg:ml-auto">
            <input id="feed-live" type="checkbox" checked={liveOnly} onChange={(e) => setLiveOnly(e.target.checked)} className="size-4 accent-[var(--color-ink)]" />
            Showing in the app now (last 7 days)
          </label>
        </div>
      </Card>
      <ErrorNote error={error} />
      {loading && !data ? (
        <Loading />
      ) : list.length === 0 ? (
        <Card><Empty title="No posts here" hint="Try every feed, or include older posts." /></Card>
      ) : (
        <div className="flex flex-col gap-4">
          {list.map((p) => {
            const author = data?.users.get(p.authorUid);
            const where = p.community === "global" ? "Global" : data?.communities.get(p.community)?.name ?? "A community";
            return (
              <Card key={p.id}>
                <div className="flex items-start gap-3">
                  <Avatar id={author?.avatarId} size={40} />
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                      <Link href={`/users/view/?uid=${p.authorUid}`} className="font-medium text-ink-strong hover:underline">{author?.displayName ?? `@${p.authorUsername}`}</Link>
                      <span className="text-sm text-muted">@{p.authorUsername} · {where} · {timeAgo(p.postedAt)}</span>
                    </div>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {p.kind === "question" ? (
                        <Badge tone="dark">Question</Badge>
                      ) : p.kind === "rank" ? (
                        <Badge tone="dark">Rank #{p.rank}</Badge>
                      ) : (
                        <>
                          <Badge tone="dark">{p.symbol} {rText(p.rMultiple)}</Badge>
                          <Badge tone={p.followedRules ? "good" : "bad"}>{p.followedRules ? "Rules kept" : "Rules broken"}</Badge>
                        </>
                      )}
                      {p.kind === "question" && <Badge tone={p.answerId ? "good" : "warn"}>{p.answerId ? "Answered" : "Open"}</Badge>}
                      {data?.pinned === p.id && <Badge tone="good">📌 Pinned to Global</Badge>}
                    </div>
                    {p.reason && <p className="mt-3 text-sm break-words text-muted">Why: {p.reason}</p>}
                    <p className="mt-2 text-[15px] leading-relaxed break-words text-ink">{p.lesson}</p>
                    <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-muted">
                      <span className="tabular">{p.claps ?? 0} likes</span>
                      <button className="tabular hover:text-ink" onClick={() => setOpen(open === p.id ? null : p.id)}>
                        {p.commentCount ?? 0} comments {open === p.id ? "▴" : "▾"}
                      </button>
                      <span className="tabular">seen by {p.reach ?? 0}</span>
                      <span className="ml-auto flex gap-2">
                        {p.community === "global" && can("pin") &&
                          (data?.pinned === p.id ? (
                            <Button size="sm" onClick={() => pin(null)}>Unpin</Button>
                          ) : (
                            <Button size="sm" onClick={() => pin(p)}>Pin to Global</Button>
                          ))}
                        <Button size="sm" variant="danger" onClick={() => remove(p)}>Delete post</Button>
                      </span>
                    </div>
                    {open === p.id && (
                      <div className="mt-4 border-t border-line-soft pt-4">
                        <Comments post={p} onChange={reload} />
                      </div>
                    )}
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
