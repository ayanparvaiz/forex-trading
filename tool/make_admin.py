#!/usr/bin/env python3
"""Lets someone into the admin panel, or out of it.

    python3 tool/make_admin.py ayan            # make @ayan an admin
    python3 tool/make_admin.py ayan --remove   # take it away
    python3 tool/make_admin.py --list          # who the admins are

An admin is a document at admins/{uid}. Only the server can write one — the
rules refuse every client — so this runs with your Firebase CLI sign-in
(`firebase login`), as the other seed tools do.
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone

from seed_firestore import access_token
from seed_university_communities import DOCS, commit, get, name, request, s, ts


def uid_of(username: str, token: str) -> str:
    claim = get(f"usernames/{username.lower()}", token)
    uid = (claim or {}).get("fields", {}).get("uid", {}).get("stringValue")
    if not uid:
        sys.exit(f"No account @{username}.")
    return uid


def main() -> None:
    token = access_token()
    if "--list" in sys.argv:
        reply = request("GET", f"{DOCS}/admins?pageSize=100", token)
        for d in reply.get("documents", []):
            f = d["fields"]
            print(f"@{f.get('username', {}).get('stringValue', '?'):<16} {d['name'].split('/')[-1]}")
        return
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    username = args[0].lstrip("@").lower()
    uid = uid_of(username, token)
    if "--remove" in sys.argv:
        reply = commit([{"delete": name(f"admins/{uid}")}], token)
        print("✗ " + reply["body"] if "__error" in reply else f"@{username} is no longer an admin")
        return
    reply = commit([{"update": {"name": name(f"admins/{uid}"), "fields": {
        "username": s(username), "addedAt": ts(datetime.now(timezone.utc))}}}], token)
    print("✗ " + reply["body"] if "__error" in reply else f"@{username} is an admin ({uid})")


if __name__ == "__main__":
    main()
