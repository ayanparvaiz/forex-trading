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
    uids: dict[str, str] = {}
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
        uids[username] = uid

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
    seed_posts(token, uids)



# --- Feed posts --------------------------------------------------------------
#
# The posts live here rather than in Dart: once they are in Firestore the app
# reads them from there, so keeping a second copy in the client would only
# create something to drift.

POSTS = [
    ("rifat", "EUR/USD", -1.0, 2,
     "H4 ডিমান্ড জোনে বুলিশ পিন বার, লন্ডন ওপেনের আগে এন্ট্রি।",
     "স্টপ লেগেছে। কিন্তু সেটআপ, সাইজ, স্টপ — সব প্ল্যান মতো ছিল। এরকম ১০টা "
     "ট্রেডের ৪টা হারলেও সমস্যা নেই। আজ কিছু বদলাব না।", True, 47, 12),
    ("imran", "GBP/USD", 4.8, 6,
     "নিউজের আগে ঢুকেছিলাম, বড় মুভ ধরব ভেবে।",
     "৪.৮R পেয়েছি, কিন্তু রিস্ক ছিল ৭%। উল্টো দিকে গেলে অ্যাকাউন্টের "
     "এক-তৃতীয়াংশ চলে যেত। এটা ভালো ট্রেড ছিল না, ভাগ্য ভালো ছিল।", False, 9, 31),
    ("nusrat", "USD/JPY", 2.1, 11,
     "ডেইলি ব্রেকআউটের রিটেস্ট, ১৫মি তে কনফার্মেশন।",
     "ব্রেকআউটে সাথে সাথে ঢুকিনি — রিটেস্টের জন্য ৪০ মিনিট অপেক্ষা করেছি। "
     "ওই অপেক্ষাটাই স্টপ ২৫ পিপ থেকে ১২ পিপে নামিয়ে দিয়েছে।", True, 63, 8),
    ("tasnim", "EUR/USD", 2.4, 4,
     "সাপ্তাহিক সাপোর্টে ডাবল বটম, নিচের উইক লম্বা ছিল।",
     "আজ মাত্র একটা ট্রেড নিয়েছি। বাকি সময় চার্ট দেখেছি কিন্তু হাত দিইনি। "
     "না-ট্রেড করাটাও একটা সিদ্ধান্ত, এটা বুঝতে ছয় মাস লেগেছে।", True, 74, 19),
    ("ishrat", "GBP/USD", -1.0, 9,
     "লন্ডন সেশনে রেঞ্জ ব্রেক, রিটেস্টে এন্ট্রি।",
     "টানা তিনটা হারলাম। রিস্ক বাড়াইনি, সাইজ বাড়াইনি, প্ল্যান বদলাইনি। "
     "হারার সিরিজে সবচেয়ে কঠিন কাজ হলো কিছু না বদলানো।", True, 118, 23),
    ("jarin", "EUR/USD", -1.0, 26,
     "সাপোর্ট ব্রেক করে আবার উপরে উঠে এসেছিল — ফলস ব্রেকডাউন ধরেছি।",
     "হেরেছি, তবু জার্নাল লিখছি কারণ ভুলটা এন্ট্রিতে না — সাইজিংয়ে। "
     "স্টপ ৩৫ পিপ দূরে ছিল, তাই লট আরও ছোট হওয়া উচিত ছিল।", True, 38, 5),
    ("raihan", "GBP/USD", 1.8, 40,
     "এশিয়ান রেঞ্জ ব্রেক, লন্ডন ওপেনে কনফার্মেশন।",
     "টার্গেটের ৮০% এ বেরিয়ে এসেছি কারণ ভয় পেয়েছিলাম। পুরো টার্গেট হিট "
     "করেছিল। ভয় আমার ০.৪R খেয়েছে।", True, 52, 17),
    ("arif", "USD/JPY", 1.5, 53,
     "H1 তে হায়ার লো, ট্রেন্ডলাইন টাচ।",
     "স্প্রেড হিসাবে ধরিনি বলে ১.৫R ভেবেছিলাম, আসলে ১.৪১R। ছোট মনে হচ্ছে, "
     "কিন্তু ১০০ ট্রেডে এটাই ৯R খেয়ে ফেলবে।", True, 56, 14),
    ("sohan", "EUR/USD", -2.6, 74,
     "ইউটিউবে একজন বলল আজ বড় মুভ হবে।",
     "অন্যের কথায় ট্রেড নিয়েছি। জিতলে জানতাম না কেন জিতলাম, হেরে জানি না "
     "কেন হারলাম। শেখার কিছুই নেই এখানে।", False, 64, 38),
    ("mehedi", "USD/JPY", -3.2, 96,
     "নিচে যাচ্ছিল, ভাবলাম ফিরবে। স্টপ সরিয়ে দিয়েছিলাম।",
     "স্টপ সরানোটাই ভুল। −১R হতো, হয়েছে −৩.২R। একটা সিদ্ধান্ত একটা লসকে "
     "তিন গুণ করে দিয়েছে।", False, 91, 44),
    ("farhana", "GBP/USD", 3.0, 120,
     "ডেইলি সাপ্লাই জোন থেকে রিজেকশন, ৪ ঘণ্টা অপেক্ষা করেছি।",
     "প্রথমবার পুরো টার্গেট পর্যন্ত ধরে রাখতে পেরেছি। হাত কাঁপছিল, তবু "
     "অর্ডার ছুঁইনি। এই একটা ট্রেড অনেক কিছু বদলে দিল।", True, 143, 27),
    ("niloy", "USD/JPY", 0.3, 147,
     "ব্রেকআউট ধরেছি, কনফার্মেশনের অপেক্ষা করিনি।",
     "লাভে বের হয়েছি কিন্তু ভয়ে বের হয়েছি, প্ল্যান অনুযায়ী না। ০.৩R মানে "
     "কার্যত ব্রেক-ইভেন — আর একটা নষ্ট সেটআপ।", False, 21, 9),
]

# How long a post stays in the feed. Matches Strings/feed expiry in the app.
POST_LIFETIME_DAYS = 7


def seed_posts(token: str, uids: dict) -> None:
    from datetime import datetime, timedelta, timezone

    now = datetime.now(timezone.utc)
    print(f"\nSeeding {len(POSTS)} posts")

    for index, (author, symbol, r, hours_ago, reason, lesson, followed,
                claps, comments) in enumerate(POSTS):
        uid = uids.get(author)
        if uid is None:
            print(f"  ✗ post {index}: no account for {author}")
            continue

        posted = now - timedelta(hours=hours_ago)
        expires = posted + timedelta(days=POST_LIFETIME_DAYS)

        result = firestore_write(
            f"posts/seed-{index}",
            {
                "authorUid": s(uid),
                "authorUsername": s(author),
                "symbol": s(symbol),
                "rMultiple": d(r),
                "reason": s(reason),
                "lesson": s(lesson),
                "followedRules": {"booleanValue": followed},
                "claps": i(claps),
                "commentCount": i(comments),
                "postedAt": {"timestampValue": posted.strftime("%Y-%m-%dT%H:%M:%SZ")},
                # Stored rather than computed, so the query can filter on it and
                # an expired post never reaches a client at all.
                "expiresAt": {"timestampValue": expires.strftime("%Y-%m-%dT%H:%M:%SZ")},
            },
            token,
        )
        if "__error" in result:
            print(f"  ✗ post {index}: {result['body'][:100]}")
        else:
            print(f"  ✓ {author:<9} {symbol:<8} {r:>+5.1f}R  {hours_ago}h ago")

if __name__ == "__main__":
    main()
