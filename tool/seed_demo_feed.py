#!/usr/bin/env python3
"""The Global feed, filled by the thirty demo traders.

    python3 tool/seed_demo_feed.py           # post what is not there yet
    python3 tool/seed_demo_feed.py --remove  # take every demo post away

Demo scaffolding, like seed_university_communities.py, whose traders write
these. Each one posts once — a trade or a question — signed in as themselves,
so the rules check every post, like and comment as they would anyone's. Then
the others like, comment and answer, and those who asked pick a best answer.

A trade post's pair and result come from that trader's own journal: a
closed trade of theirs that matches what the post says (a win or a loss,
rules kept or not), so the feed never claims a trade the journal lacks.

Posts are dated over the last three days and, as in the app, last seven
from when they were posted — after that the feed no longer shows them, and
running this again posts afresh. A trader whose post is still up is left
alone. --remove deletes the demo traders' Global posts, with their likes,
comments and views.
"""

from __future__ import annotations

import random
import sys
import time
from datetime import datetime, timedelta, timezone

from seed_firestore import access_token, web_api_key
from seed_trades import sign_in
from seed_university_communities import (
    DOCS,
    TRADERS,
    commit,
    get,
    i,
    name,
    new_id,
    request,
    s,
    ts,
)

# (username, kind, hours ago, …)
#   trade:    outcome ('win' | 'loss'), rules kept?, why, lesson — where
#             {pair} and {r} become the journal trade's own
#   question: the question
POSTS = [
    ("tahmid_h", "trade", 2, "win", True,
     "H4 তে সাপোর্ট জোন, H1 এ বুলিশ এনগালফিং। স্টপ জোনের নিচে।",
     "Target এ পৌঁছানোর আগে দুবার মনে হয়েছিল ক্লোজ করে দিই। প্ল্যান মেনে বসে ছিলাম, ফল পেয়েছি।"),
    ("nafisa_r", "question", 3,
     "Bangladesh সময়ে EUR/USD এর জন্য কোন সেশন সবচেয়ে ভালো? সন্ধ্যার London-New York overlap এ নাকি দুপুরে London open এ?"),
    ("sakib_c", "trade", 5, "loss", True,
     "Daily trend up, H1 pullback to 50 EMA.",
     "Stopped out, but the stop was where my plan said. −1R is a normal day, not a disaster."),
    ("raisa_a", "trade", 7, "win", True,
     "Range এর উপরের দিক থেকে sell, রিস্ক ১%।",
     "ছোট সাইজে ট্রেড করলে মাথা ঠান্ডা থাকে। এটাই আমার সবচেয়ে বড় শিক্ষা এই মাসে।"),
    ("fahim_i", "trade", 9, "loss", False,
     "News এর আগে ঢুকেছিলাম, setup ছিল না।",
     "NFP এর ঠিক আগে ঢোকা ভুল ছিল। এখন থেকে বড় নিউজের ৩০ মিনিট আগে-পরে কোনো ট্রেড না।"),
    ("labiba_h", "question", 11,
     "যারা জার্নাল লেখেন, প্রতিটা ট্রেডের পর কতক্ষণ সময় দেন? আমার মনে হয় ৫ মিনিটে ঠিকমতো লেখা হয় না।"),
    ("mahir_r", "trade", 13, "win", True,
     "London open এ previous day high ব্রেক, retest এর পর entry।",
     "Retest এর জন্য অপেক্ষা করাটাই কঠিন। আগে হলে breakout এই ঢুকে যেতাম।"),
    ("tanjila_a", "trade", 15, "loss", True,
     "{pair} trendline bounce.",
     "Spread বেশি ছিল, ছোট স্টপে সেটা অনেকটা খেয়ে ফেলল। স্টপ একটু বড় রাখতে হবে, সাইজ ছোট।"),
    ("rafsan_k", "trade", 17, "win", False,
     "Momentum দেখে ঢুকেছিলাম, রিস্ক বেশি নিয়েছিলাম।",
     "জিতেছি, কিন্তু রিস্ক ছিল ৩%। জেতা ট্রেডও খারাপ ট্রেড হতে পারে — অ্যাপ সেটা ধরিয়ে দিল।"),
    ("samira_h", "question", 19,
     "1% risk রাখলে USD/JPY তে lot size কীভাবে বের করেন? pip value টা গুলিয়ে যায়।"),
    ("ashik_m", "trade", 21, "loss", False,
     "পরপর দুটো লসের পর রাগ থেকে ঢুকেছিলাম।",
     "Revenge trade। তিনটা লস একদিনে। আজ থেকে daily loss limit 2% চালু করে দিলাম।"),
    ("nabila_s", "trade", 24, "win", True,
     "Asian range breakout, London session এ।",
     "Checklist টা প্রতিবার পড়ি — ‘দাম তাড়া করছি না’ লাইনটা অনেক ট্রেড থেকে বাঁচিয়েছে।"),
    ("zarif_a", "trade", 26, "win", True,
     "Weekly level + H4 double bottom.",
     "Higher timeframe level ছাড়া এখন আর ট্রেড নিই না। কম ট্রেড, ভালো ট্রেড।"),
    ("maliha_c", "question", 28,
     "দিনে সর্বোচ্চ কয়টা ট্রেড নেওয়া উচিত বলে মনে করেন? আমি ৩টা লিমিট রেখেছি।"),
    ("arnab_d", "trade", 30, "loss", True,
     "{pair} breakout failed, stop hit.",
     "False breakout। তবু স্টপ সরাইনি — এই একটা অভ্যাসই অ্যাকাউন্ট বাঁচায়।"),
    ("tasfia_k", "trade", 33, "win", True,
     "Pullback to previous resistance turned support.",
     "Partial close না করে পুরো টার্গেট পর্যন্ত রেখেছি। R:R 1:2 এর মানে এখন বুঝি।"),
    ("nayeem_u", "trade", 36, "loss", False,
     "প্ল্যান ছাড়া ঢুকেছিলাম, কারণ লেখা ছিল এক লাইনে।",
     "কারণ লেখার জায়গায় ভালো করে লিখলে এই ট্রেডটা নিতামই না।"),
    ("sumaiya_n", "question", 39,
     "H1 না H4 — নতুনদের জন্য কোন টাইমফ্রেম দিয়ে শুরু করা ভালো?"),
    ("rakib_h", "trade", 42, "win", True,
     "Trend continuation after London open.",
     "Mood এ ‘শান্ত’ দিয়ে নেওয়া ট্রেডগুলোর ফল সবচেয়ে ভালো — জার্নাল নিজেই দেখিয়ে দিল।"),
    ("lamia_i", "trade", 45, "win", True,
     "Support bounce, bullish pin bar on H1.",
     "এক সপ্তাহ সব নিয়ম মেনেছি, ক্যালেন্ডার পুরো সবুজ। স্কোর ৯০ পার হয়েছে।"),
    ("shafin_a", "trade", 48, "loss", False,
     "স্টপ সরিয়ে দূরে নিয়েছিলাম।",
     "স্টপ সরিয়ে দূরে নেওয়ায় লসটাও বড় হলো। আর কখনো না।"),
    ("fariha_t", "trade", 51, "win", True,
     "{pair} London session pullback.",
     "Weekly challenge এ বন্ধুর সাথে প্রতিযোগিতা করে নিয়ম মানা অনেক সহজ লাগছে।"),
    ("towhid_a", "question", 54,
     "Revenge trade থামাতে আপনারা কী করেন? লসের পর হাত নিশপিশ করে।"),
    ("jannatul_f", "trade", 57, "loss", True,
     "Double top short, stop above the high.",
     "লস হলেও প্ল্যান মেনেছি, তাই খারাপ লাগছে না। পরের সেটআপের অপেক্ষা।"),
    ("imtiaz_h", "trade", 60, "win", True,
     "London-New York overlap এ trend continuation।",
     "Overlap এর সময় মুভ ভালো পাই। সন্ধ্যা ৭টা থেকে ১০টা — আমার ট্রেডিং টাইম।"),
    ("ayesha_s", "trade", 62, "win", True,
     "Range low থেকে buy, স্টপ range এর নিচে।",
     "দৈনিক ১০,০০০ পয়েন্টে প্র্যাকটিস করে ভয়টা কেটে যাচ্ছে।"),
    ("nahid_h", "trade", 64, "loss", False,
     "Overtrading — এক দিনে ৬টা ট্রেড।",
     "অ্যাপ ৪ নম্বর ট্রেডের পরেই সাবধান করেছিল। শুনিনি। এখন দিনে ২টা।"),
    ("mahjabin_r", "trade", 66, "win", True,
     "H4 support, entry on H1 confirmation.",
     "Patience pays. Two days waiting for the setup, one trade, {r}."),
    ("asif_i", "trade", 68, "loss", True,
     "{pair} trend trade, stop hit on news spike.",
     "স্টপ ছিল বলেই −1R এ থেমেছে। স্টপ ছাড়া হলে কী হতো ভাবতেই ভয় লাগে।"),
    ("nowshin_a", "trade", 71, "win", True,
     "Pullback entry, R:R 1:2.",
     "প্রথম মাসে লাভ না খুঁজে নিয়ম খুঁজেছি। এখন ফল আসছে।"),
]

# Answers and replies: (on whose post, by whom, words, best answer?)
COMMENTS = [
    ("nafisa_r", "tahmid_h", "আমার অভিজ্ঞতায় সন্ধ্যা ৭টা থেকে ১০টা — London-New York overlap। মুভ বেশি, স্প্রেড কম।", True),
    ("nafisa_r", "imtiaz_h", "Overlap 👍 দুপুরের London open এ fake move বেশি দেখি।", False),
    ("labiba_h", "raisa_a", "১০ মিনিট দিই। কারণ, কী শিখলাম, আর পরের বার কী করব — তিনটা লাইন।", True),
    ("labiba_h", "lamia_i", "আমি দিনের শেষে একবারে লিখি, ট্রেডের সাথে সাথে না।", False),
    ("samira_h", "zarif_a", "অ্যাপের ট্রেড স্ক্রিনে রিস্ক % আর স্টপ দিলেই লট সাইজ বের করে দেয়। JPY তে pip value আলাদা, ওটা নিজে হিসাব করতে হয় না।", True),
    ("samira_h", "mahir_r", "Risk calculator টা ব্যবহার করে দেখো, ওখানে pip value দেখায়।", False),
    ("maliha_c", "tasfia_k", "আমিও ৩টা। চতুর্থটা সবসময় বাজে হয় 😅", True),
    ("maliha_c", "nahid_h", "৬টা নিয়ে শিখেছি — ২টাই যথেষ্ট।", False),
    ("sumaiya_n", "rakib_h", "H4। কম noise, সিদ্ধান্ত নেওয়ার সময় পাওয়া যায়।", True),
    ("sumaiya_n", "fariha_t", "H4 এ লেভেল, H1 এ entry — এভাবে শুরু করো।", False),
    ("towhid_a", "nabila_s", "লসের পর ১ ঘণ্টা চার্ট বন্ধ। আর daily loss limit চালু রাখি, তখন বাটনই বন্ধ হয়ে যায়।", True),
    ("towhid_a", "ashik_m", "আমিও এই সমস্যায় ভুগছি। Loss limit আজ থেকে চালু করলাম।", False),
    ("tahmid_h", "nafisa_r", "Discipline 🔥", False),
    ("fahim_i", "sakib_c", "News এর সময় spread ও অনেক বাড়ে, খেয়াল রেখো।", False),
    ("rafsan_k", "tanjila_a", "সৎ লেখার জন্য ধন্যবাদ। জেতা ট্রেড নিয়েও এভাবে কেউ বলে না।", False),
    ("ashik_m", "samira_h", "ভালো সিদ্ধান্ত। ২% লিমিট আমাকেও অনেক বাঁচিয়েছে।", False),
    ("shafin_a", "towhid_a", "স্টপ সরানো আমারও সবচেয়ে বড় ভুল ছিল।", False),
    ("lamia_i", "jannatul_f", "সবুজ ক্যালেন্ডার দেখতে কী যে ভালো লাগে 😄", False),
    ("nahid_h", "ayesha_s", "২টা লিমিট ভালো সিদ্ধান্ত 🤝", False),
    ("mahjabin_r", "asif_i", "Two days of waiting is the hard part. Well done.", False),
]

TOKEN_CACHE: dict[str, tuple[str, str]] = {}
PROFILE_CACHE: dict[str, dict] = {}


def who(username: str, key: str) -> tuple[str, str]:
    if username not in TOKEN_CACHE:
        TOKEN_CACHE[username] = sign_in(username, key)
    return TOKEN_CACHE[username]


def profile(uid: str, admin: str) -> dict:
    if uid not in PROFILE_CACHE:
        PROFILE_CACHE[uid] = (get(f"users/{uid}", admin) or {}).get("fields", {})
    return PROFILE_CACHE[uid]


def field(doc: dict, key: str):
    v = doc.get(key, {})
    for t in ("stringValue", "doubleValue", "integerValue", "booleanValue", "timestampValue"):
        if t in v:
            return float(v[t]) if t == "integerValue" else v[t]
    if "arrayValue" in v:
        return [x.get("stringValue") for x in v["arrayValue"].get("values", [])]
    return None


def r_of(t: dict) -> float | None:
    entry, stop, exit_ = field(t, "entryPrice"), field(t, "stopPrice"), field(t, "exitPrice")
    if None in (entry, stop, exit_) or entry == stop:
        return None
    sign = 1 if field(t, "direction") == "buy" else -1
    return (exit_ - entry) * sign / abs(entry - stop)


def pick_trade(uid: str, outcome: str, kept: bool, admin: str) -> tuple[str, float] | None:
    """A closed trade from their journal that is what the post says it is."""
    reply = request("GET", f"{DOCS}/users/{uid}/trades?pageSize=300", admin)
    trades = [d.get("fields", {}) for d in reply.get("documents", [])]
    for t in sorted(trades, key=lambda t: field(t, "closedAt") or "", reverse=True):
        r = r_of(t)
        if r is None:
            continue
        clean = not (field(t, "violations") or [])
        if (r > 0) == (outcome == "win") and clean == kept:
            return field(t, "symbol"), round(r, 2)
    return None


def demo_uids(key: str) -> dict[str, str]:
    return {u: who(u, key)[0] for rows in TRADERS.values() for (u, *_rest) in rows}


def live_posts(admin: str, uids: set[str]) -> dict[str, str]:
    """The demo traders' Global posts still showing: author uid → post id."""
    reply = request("POST", f"{DOCS}:runQuery", admin, {"structuredQuery": {
        "from": [{"collectionId": "posts"}],
        "where": {"fieldFilter": {"field": {"fieldPath": "expiresAt"}, "op": "GREATER_THAN",
                                  "value": ts(datetime.now(timezone.utc))}},
        "limit": 500,
    }})
    found = {}
    for row in reply if isinstance(reply, list) else []:
        doc = row.get("document")
        if not doc:
            continue
        author = field(doc["fields"], "authorUid")
        if author in uids and field(doc["fields"], "community") == "global":
            found[author] = doc["name"].split("/")[-1]
    return found


def seed() -> None:
    admin = access_token()
    key = web_api_key()
    uids = demo_uids(key)
    existing = live_posts(admin, set(uids.values()))
    now = datetime.now(timezone.utc)
    posts: dict[str, str] = {}  # username → post id

    print("Posts")
    for spec in POSTS:
        username, kind, hours = spec[0], spec[1], spec[2]
        uid, token = who(username, key)
        if uid in existing:
            posts[username] = existing[uid]
            print(f"  · @{username}: still up — left as it is")
            continue
        at = now - timedelta(hours=hours, minutes=random.Random(username).randint(0, 50))
        fields = {
            "authorUid": s(uid),
            "authorUsername": s(username),
            "community": s("global"),
            "claps": i(0),
            "commentCount": i(0),
            "reach": i(0),
            "postedAt": ts(at),
            "expiresAt": ts(at + timedelta(days=7)),
        }
        if kind == "question":
            fields |= {"kind": s("question"), "lesson": s(spec[3])}
        else:
            outcome, kept, why, lesson = spec[3:]
            picked = pick_trade(uid, outcome, kept, admin)
            if not picked:
                print(f"  ✗ @{username}: no {outcome} with rules {'kept' if kept else 'broken'} in the journal")
                continue
            symbol, r = picked
            fill = {"pair": symbol, "r": f"{r:+.1f}R"}
            fields |= {"kind": s("trade"), "symbol": s(symbol), "rMultiple": {"doubleValue": r},
                       "reason": s(why.format(**fill)), "lesson": s(lesson.format(**fill)),
                       "followedRules": {"booleanValue": kept}}
        pid = new_id()
        reply = commit([{"update": {"name": name(f"posts/{pid}"), "fields": fields},
                         "currentDocument": {"exists": False}}], token)
        if "__error" in reply:
            print(f"  ✗ @{username}: {reply['body'][:160]}")
            continue
        posts[username] = pid
        label = "?" if kind == "question" else f"{fields['symbol']['stringValue']} {r:+.2f}R"
        print(f"  ✓ @{username:<11} {label}")

    print("\nLikes")
    rng = random.Random(2026)
    names = list(uids)
    for author, pid in posts.items():
        fans = rng.sample([u for u in names if u != author], rng.randint(2, 9))
        n = 0
        for fan in fans:
            uid, token = who(fan, key)
            reply = commit([
                {"update": {"name": name(f"posts/{pid}/claps/{uid}"), "fields": {"uid": s(uid)}},
                 "updateTransforms": [{"fieldPath": "at", "setToServerValue": "REQUEST_TIME"}],
                 "currentDocument": {"exists": False}},
                {"transform": {"document": name(f"posts/{pid}"), "fieldTransforms": [
                    {"fieldPath": "claps", "increment": i(1)}]}},
            ], token)
            if "__error" not in reply:
                n += 1
        print(f"  @{author:<11} {n} likes")

    print("\nComments")
    for on, by, body, best in COMMENTS:
        pid = posts.get(on)
        if not pid:
            continue
        uid, token = who(by, key)
        p = profile(uid, admin)
        cid = new_id()
        reply = commit([
            {"update": {"name": name(f"posts/{pid}/comments/{cid}"), "fields": {
                "authorUid": s(uid), "authorUsername": s(by),
                "authorName": s(field(p, "displayName") or by),
                "authorAvatarId": i(field(p, "avatarId") or 1), "body": s(body)}},
             "updateTransforms": [{"fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"}],
             "currentDocument": {"exists": False}},
            {"transform": {"document": name(f"posts/{pid}"), "fieldTransforms": [
                {"fieldPath": "commentCount", "increment": i(1)}]}},
        ], token)
        if "__error" in reply:
            print(f"  ✗ @{by} on @{on}: {reply['body'][:160]}")
            continue
        print(f"  @{by:<11} → @{on}: {body[:50]}{'…' if len(body) > 50 else ''}")
        if best:
            _, asker = who(on, key)
            pick = commit([{"update": {"name": name(f"posts/{pid}"), "fields": {"answerId": s(cid)}},
                            "updateMask": {"fieldPaths": ["answerId"]}}], asker)
            if "__error" not in pick:
                print(f"    ✓ @{on} picked it as the best answer")
        time.sleep(0.3)


def remove() -> None:
    admin = access_token()
    key = web_api_key()
    uids = demo_uids(key)
    posts = live_posts(admin, set(uids.values()))
    for uid, pid in posts.items():
        writes = []
        for sub in ("claps", "comments", "views"):
            reply = request("GET", f"{DOCS}/posts/{pid}/{sub}?pageSize=300", admin)
            writes += [{"delete": d["name"]} for d in reply.get("documents", [])]
        writes.append({"delete": name(f"posts/{pid}")})
        reply = commit(writes, admin)
        print(("✗ " if "__error" in reply else "✓ ") + f"post {pid} and {len(writes) - 1} likes, comments, views")


if __name__ == "__main__":
    remove() if "--remove" in sys.argv else seed()
