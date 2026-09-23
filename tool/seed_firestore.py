#!/usr/bin/env python3
"""Seeds the demo accounts into Firebase Auth and Firestore.

Run once per environment:

    python3 tool/seed_firestore.py

Reads the account list straight out of ``app/lib/data/seed_accounts.dart`` so
the app and the database cannot describe different people. Re-running is safe:
accounts that already exist are skipped.

Authentication comes from the Firebase CLI's stored credentials, so whoever
runs this must already be logged in with ``firebase login``. Firestore writes
go through the admin endpoint and therefore bypass security rules — which is
the point, since the rules deliberately forbid a client from setting its own
scores.

This is demo scaffolding. Every seeded account shares one published password,
which has to go before real people are on the platform.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

PROJECT = "forex-9f21b"
EMAIL_DOMAIN = "users.forex-9f21b.app"
SEED_FILE = Path(__file__).resolve().parent.parent / "app/lib/data/seed_accounts.dart"

# Public OAuth client shipped inside firebase-tools itself.
CLI_CLIENT_ID = (
    "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
)
CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"


def access_token() -> str:
    config = Path.home() / ".config/configstore/firebase-tools.json"
    if not config.exists():
        sys.exit("Not logged in. Run: firebase login")

    refresh = json.loads(config.read_text())["tokens"]["refresh_token"]
    body = urllib.parse.urlencode(
        {
            "client_id": CLI_CLIENT_ID,
            "client_secret": CLI_CLIENT_SECRET,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        }
    ).encode()
    request = urllib.request.Request("https://oauth2.googleapis.com/token", data=body)
    return json.load(urllib.request.urlopen(request))["access_token"]


def web_api_key() -> str:
    options = SEED_FILE.parent.parent / "firebase_options.dart"
    match = re.search(r"apiKey: '([^']+)'", options.read_text())
    if not match:
        sys.exit("No apiKey in firebase_options.dart — run flutterfire configure")
    return match.group(1)


def parse_seed_accounts() -> list[dict]:
    """Pulls the account list out of the Dart source.

    Parsing the real file rather than keeping a copy here means the seeded data
    and the app's own list can never drift apart.
    """
    source = SEED_FILE.read_text()

    # Scope to the list literal first. Matching "SeedAccount(" across the whole
    # file also catches the class's own constructor and its toTrader() body.
    start = source.index("static const all = <SeedAccount>[")
    end = source.index("\n  ];", start)
    listing = source[start:end]

    blocks = re.findall(r"SeedAccount\((.*?)\n    \)", listing, re.S)

    accounts = []
    for block in blocks:
        def field(name: str, cast=str):
            # Anchored to the start of the line. Unanchored, "name" also
            # matches the tail of "username" and every account ends up
            # display-named after its own handle.
            match = re.search(rf"^\s*{name}:\s*([^,\n]+),", block, re.M)
            if not match:
                return None
            raw = match.group(1).strip().strip("'")
            if cast is str:
                return raw
            if cast is int:
                return int(float(raw))
            return cast(raw)

        username = field("username")
        if username == "owner":
            username = "ayan"

        accounts.append(
            {
                "username": username,
                "name": field("name"),
                "avatarId": field("avatarId", int),
                "gender": field("gender").split(".")[-1],
                "language": field("language").split(".")[-1],
                "badgePoints": field("badgePoints", int),
                "totalR": field("totalR", float),
                "disciplineScore": field("disciplineScore", float),
                "tradeCount": field("tradeCount", int),
                "winRate": field("winRate", float),
                "journalStreak": field("journalStreak", int),
            }
        )
    return accounts


def post(url: str, body: dict, token: str | None = None) -> dict:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    try:
        return json.load(urllib.request.urlopen(request))
    except urllib.error.HTTPError as error:
        return {"__error": error.code, "body": error.read().decode()[:300]}


def firestore_write(path: str, fields: dict, token: str) -> dict:
    """PATCH creates or replaces a document at ``path``."""
    url = (
        f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
        f"/databases/(default)/documents/{path}"
    )
    request = urllib.request.Request(
        url,
        method="PATCH",
        data=json.dumps({"fields": fields}).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        return json.load(urllib.request.urlopen(request))
    except urllib.error.HTTPError as error:
        return {"__error": error.code, "body": error.read().decode()[:300]}


def s(value):
    return {"stringValue": str(value)}


def i(value):
    return {"integerValue": str(int(value))}


def d(value):
    return {"doubleValue": float(value)}


def main() -> None:
    password = os.environ.get("SEED_PASSWORD", "demo1234")
    token = access_token()
    key = web_api_key()
    accounts = parse_seed_accounts()

    print(f"Seeding {len(accounts)} accounts into {PROJECT}\n")

    created = skipped = failed = 0
    for account in accounts:
        username = account["username"]
        email = f"{username}@{EMAIL_DOMAIN}"

        result = post(
            f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={key}",
            {"email": email, "password": password, "returnSecureToken": True},
        )

        if "__error" in result:
            if "EMAIL_EXISTS" in result["body"]:
                # Already seeded. Sign in instead so the profile can be refreshed.
                result = post(
                    "https://identitytoolkit.googleapis.com/v1/"
                    f"accounts:signInWithPassword?key={key}",
                    {"email": email, "password": password, "returnSecureToken": True},
                )
                if "__error" in result:
                    print(f"  ✗ {username}: {result['body']}")
                    failed += 1
                    continue
                skipped += 1
            else:
                print(f"  ✗ {username}: {result['body']}")
                failed += 1
                continue
        else:
            created += 1

        uid = result["localId"]

        profile = firestore_write(
            f"users/{uid}",
            {
                "username": s(username),
                "displayName": s(account["name"]),
                "gender": s(account["gender"]),
                "language": s(account["language"]),
                "avatarId": i(account["avatarId"]),
                "cohort": s(""),
                "createdAt": s("2026-09-01T00:00:00.000"),
                "disciplineScore": d(account["disciplineScore"]),
                "badgePoints": i(account["badgePoints"]),
                "tradeCount": i(account["tradeCount"]),
                "winRate": d(account["winRate"]),
                "journalStreak": i(account["journalStreak"]),
                "totalR": d(account["totalR"]),
            },
            token,
        )
        claim = firestore_write(f"usernames/{username}", {"uid": s(uid)}, token)

        if "__error" in profile or "__error" in claim:
            print(f"  ✗ {username}: firestore write failed")
            failed += 1
            continue

        print(f"  ✓ {username:<9} uid={uid[:10]}…  badge={account['badgePoints']:<4}"
              f" discipline={account['disciplineScore']:.0f}")

    print(f"\nauth created {created}, already existed {skipped}, failed {failed}")


if __name__ == "__main__":
    main()
