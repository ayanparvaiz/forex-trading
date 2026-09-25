#!/usr/bin/env python3
"""Sets every post's like, comment and reach counts to what is really there.

    python3 tool/recount_posts.py            # fix them
    python3 tool/recount_posts.py --dry-run  # only say what is wrong

A post's counters are kept by the app, one at a time, beside the like, the
comment or the view they count — the rules allow nothing else. They can
still drift: a write that half-failed long ago, or numbers that were typed
in rather than earned (the first seed did exactly that). This counts the
documents under each post and writes the true numbers back.

Uses the Firebase CLI's login, like seed_firestore.py, so it writes past the
rules. Counting is one aggregate read per thousand documents. A like landing
between the count and the write would be missed; running it again catches it.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

from seed_firestore import PROJECT, access_token

BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

# The counter on the post, and the collection under it that it counts.
COUNTERS = {"claps": "claps", "commentCount": "comments", "reach": "views"}


def call(url: str, token: str, body: dict | None = None, method: str | None = None):
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode() if body is not None else None,
        method=method or ("POST" if body is not None else "GET"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        return json.load(urllib.request.urlopen(request))
    except urllib.error.HTTPError as error:
        sys.exit(f"{error.code} from {url}: {error.read().decode()[:300]}")


def all_posts(token: str) -> list[dict]:
    posts, page = [], ""
    while True:
        url = f"{BASE}/posts?pageSize=300" + (f"&pageToken={page}" if page else "")
        body = call(url, token)
        posts += body.get("documents", [])
        page = body.get("nextPageToken", "")
        if not page:
            return posts


def count_under(post_id: str, collection: str, token: str) -> int:
    body = call(
        f"{BASE}/posts/{post_id}:runAggregationQuery",
        token,
        {
            "structuredAggregationQuery": {
                "structuredQuery": {"from": [{"collectionId": collection}]},
                "aggregations": [{"alias": "n", "count": {}}],
            }
        },
    )
    return int(body[0]["result"]["aggregateFields"]["n"]["integerValue"])


def main() -> None:
    dry_run = "--dry-run" in sys.argv
    token = access_token()
    posts = all_posts(token)
    fixed = 0

    for doc in posts:
        post_id = doc["name"].rsplit("/", 1)[1]
        fields = doc.get("fields", {})
        stored = {k: int(fields.get(k, {}).get("integerValue", 0)) for k in COUNTERS}
        real = {k: count_under(post_id, c, token) for k, c in COUNTERS.items()}
        if stored == real:
            continue

        fixed += 1
        change = ", ".join(f"{k} {stored[k]} → {real[k]}" for k in COUNTERS if stored[k] != real[k])
        print(f"  {post_id:<24} {change}")
        if dry_run:
            continue

        mask = "&".join(f"updateMask.fieldPaths={k}" for k in COUNTERS)
        call(
            f"{BASE}/posts/{post_id}?{mask}&currentDocument.exists=true",
            token,
            {"fields": {k: {"integerValue": str(v)} for k, v in real.items()}},
            method="PATCH",
        )

    verb = "would fix" if dry_run else "fixed"
    print(f"\n{len(posts)} posts, {verb} {fixed}.")


if __name__ == "__main__":
    main()
