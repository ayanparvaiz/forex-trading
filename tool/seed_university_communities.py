#!/usr/bin/env python3
"""Five university communities, and thirty demo traders to fill them.

    python3 tool/seed_university_communities.py           # create what is missing
    python3 tool/seed_university_communities.py --chat    # a first conversation in each
    python3 tool/seed_university_communities.py --remove  # take all of it away

Demo scaffolding, like seed_firestore.py: until real students arrive, this
shows what a community looks like with people in it. The universities are
the five public engineering universities — BUET, RUET, CUET, KUET and DUET —
under their full English names, six traders each, the first of the six its
admin.

Nobody's scores are typed in. Each trader gets a journal of closed trades
(seed_trades.build_trades, from a brief of the kind of trader they are), and
the stats worker scores it through the same endpoint the app uses — so their
places on the leaderboard, and their communities' points, are whatever those
trades earn.

The conversations (--chat) are written by the members themselves, signed in
as them, so the rules check every message as they would anyone's — which is
also why each one is timed as it is sent. A room that already has messages
is left alone.

Re-running is safe: an account, a journal or a community that is already
there is left as it is. --remove deletes the accounts the way the app does
(the worker erases everything, then the sign-in goes), then the communities,
their rooms and their names, so none of it lingers once real people come.
"""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

from seed_firestore import (
    EMAIL_DOMAIN,
    PROJECT,
    access_token,
    firestore_write,
    post,
    web_api_key,
)
from seed_trades import PASSWORD, build_trades, recompute, sign_in, to_value

WORKER = "https://forex-trading-stats.forex-trading-stats.workers.dev"
BASE = f"projects/{PROJECT}/databases/(default)/documents"
DOCS = f"https://firestore.googleapis.com/v1/{BASE}"

# Profile pictures to hand out, in turn. Ids from app/lib/data/avatars.dart.
AVATARS = [7, 24, 11, 16, 12, 13, 17, 15, 1, 18, 2, 3, 19, 4, 5, 20, 6, 8, 21,
           9, 14, 22, 10, 23]

# (username, name, gender, discipline, win rate, total R, trades, streak).
# A brief for the journal, not the answer: the worker scores what comes out.
TRADERS = {
    "buet": [
        ("tahmid_h", "Tahmid Hasan", "male", 96, 0.56, 18.0, 74, 12),
        ("nafisa_r", "Nafisa Rahman", "female", 93, 0.52, 11.5, 61, 9),
        ("sakib_c", "Sakib Chowdhury", "male", 88, 0.49, 6.0, 55, 4),
        ("raisa_a", "Raisa Ahmed", "female", 91, 0.54, 9.0, 47, 7),
        ("fahim_i", "Fahim Islam", "male", 79, 0.46, 2.5, 66, 2),
        ("labiba_h", "Labiba Haque", "female", 85, 0.50, 4.0, 38, 5),
    ],
    "ruet": [
        ("mahir_r", "Mahir Rahman", "male", 90, 0.51, 8.0, 58, 8),
        ("tanjila_a", "Tanjila Akter", "female", 86, 0.48, 3.5, 44, 6),
        ("rafsan_k", "Rafsan Kabir", "male", 72, 0.53, 12.0, 82, 1),
        ("samira_h", "Samira Hossain", "female", 89, 0.47, 1.5, 36, 3),
        ("ashik_m", "Ashik Mahmud", "male", 68, 0.44, -3.0, 71, 0),
        ("nabila_s", "Nabila Sultana", "female", 83, 0.50, 5.0, 29, 4),
    ],
    "cuet": [
        ("zarif_a", "Zarif Ahmed", "male", 94, 0.55, 14.0, 69, 10),
        ("maliha_c", "Maliha Chowdhury", "female", 92, 0.51, 7.5, 52, 8),
        ("arnab_d", "Arnab Das", "male", 87, 0.48, 3.0, 60, 5),
        ("tasfia_k", "Tasfia Karim", "female", 90, 0.53, 8.5, 41, 6),
        ("nayeem_u", "Nayeem Uddin", "male", 76, 0.50, 6.5, 77, 1),
        ("sumaiya_n", "Sumaiya Noor", "female", 84, 0.46, 0.5, 33, 3),
    ],
    "kuet": [
        ("rakib_h", "Rakib Hasan", "male", 89, 0.50, 7.0, 63, 7),
        ("lamia_i", "Lamia Islam", "female", 91, 0.49, 4.5, 48, 9),
        ("shafin_a", "Shafin Ahmed", "male", 74, 0.55, 15.0, 88, 0),
        ("fariha_t", "Fariha Tabassum", "female", 87, 0.52, 6.0, 39, 5),
        ("towhid_a", "Towhid Alam", "male", 70, 0.43, -5.5, 57, 1),
        ("jannatul_f", "Jannatul Ferdous", "female", 82, 0.47, 1.0, 27, 2),
    ],
    "duet": [
        ("imtiaz_h", "Imtiaz Hossain", "male", 88, 0.52, 9.5, 64, 6),
        ("ayesha_s", "Ayesha Siddiqua", "female", 90, 0.50, 5.5, 45, 8),
        ("nahid_h", "Nahid Hasan", "male", 66, 0.48, 2.0, 79, 0),
        ("mahjabin_r", "Mahjabin Rahman", "female", 85, 0.51, 4.0, 35, 4),
        ("asif_i", "Asif Iqbal", "male", 78, 0.45, -1.5, 53, 2),
        ("nowshin_a", "Nowshin Anjum", "female", 81, 0.49, 2.5, 30, 3),
    ],
}

# Picture ids from app/lib/data/community_avatars.dart.
COMMUNITIES = [
    dict(
        key="buet",
        id="buetuni",
        name="Bangladesh University of Engineering and Technology",
        avatar=22,  # crown
        description="BUET, Dhaka. Engineers who backtest a setup before "
        "trusting it, and journal every trade — win or lose.",
    ),
    dict(
        key="ruet",
        id="ruetuni",
        name="Rajshahi University of Engineering & Technology",
        avatar=4,  # chart
        description="RUET, Rajshahi. Patient traders from the north: we wait "
        "for the retest, size small and never move a stop.",
    ),
    dict(
        key="cuet",
        id="cuetuni",
        name="Chittagong University of Engineering & Technology",
        avatar=18,  # wave
        description="CUET, Chattogram. By the sea and riding the waves — one "
        "planned trade at a time.",
    ),
    dict(
        key="kuet",
        id="kuetuni",
        name="Khulna University of Engineering & Technology",
        avatar=25,  # anchor
        description="KUET, Khulna. Anchored in risk management: one percent a "
        "trade, and a journal every day.",
    ),
    dict(
        key="duet",
        id="duetuni",
        name="Dhaka University of Engineering & Technology, Gazipur",
        avatar=19,  # bolt
        description="DUET, Gazipur. Quick to learn, careful to act — "
        "practising forex the disciplined way.",
    ),
]


# A first conversation in each community: (username, text, index of the
# message it replies to). About the process, never a call — nobody here
# hands out entries, and the members say so.
CHATS = {
    "buet": [
        ("tahmid_h", "Welcome to the BUET community, everyone! One rule here: share "
         "your process, not signals. And journal every trade 📓", None),
        ("nafisa_r", "Thanks Tahmid bhai! Nine days of journaling in a row now 🔥", None),
        ("sakib_c", "London session was choppy today. Took one EUR/USD trade at the H4 "
         "support and got stopped out at −1R. The stop was exactly where the plan "
         "said.", None),
        ("labiba_h", "A −1R that follows the plan is a good trade. What did you risk?", 2),
        ("sakib_c", "1% of the day's points. Kept it small after last week 😅", 3),
        ("raisa_a", "Backtested the retest setup on 60 old GBP/USD charts over the "
         "weekend — about 52% at 2R. Worth sticking with.", None),
        ("fahim_i", "Honest confession: I moved my stop yesterday. A −1R became −2.3R, "
         "and my discipline score took the hit 😬", None),
        ("tahmid_h", "Good that you wrote it down. Sticky note next to the laptop: the "
         "stop never moves against you.", 6),
        ("labiba_h", "Can someone explain how community points work?", None),
        ("nafisa_r", "Everyone of ours in the leaderboard's top 50 adds points — #1 is "
         "worth 50, #50 is worth 1. So careful trading moves all of us up.", 8),
        ("raisa_a", "And we're #1 right now 🏆 Let's keep it that way — no revenge "
         "trades!", None),
        ("fahim_i", "Noted 🙏 One trade tomorrow, max.", None),
        ("tahmid_h", "That's the spirit. Chart review after class tomorrow, 9 pm?", None),
        ("labiba_h", "Count me in 👍", 12),
    ],
    "ruet": [
        ("mahir_r", "Assalamu alaikum, RUET traders! This is our space — post your "
         "lessons, ask anything, help each other out.", None),
        ("tanjila_a", "Excited to be here! Just closed a USD/JPY trade at +1.8R ✅", None),
        ("rafsan_k", "+3.5R on GBP/USD today 🚀 went in right before the news", None),
        ("samira_h", "Congrats, but a news trade is a coin flip. What was your risk on "
         "that one?", 2),
        ("rafsan_k", "…about 5% 😅 I know, I know", 3),
        ("mahir_r", "A win at 5% risk teaches the wrong lesson. The board ranks "
         "discipline, not R — you'd climb faster at 1%.", 4),
        ("ashik_m", "Three losses in a row this week. Thinking of doubling my size to "
         "win it back.", None),
        ("nabila_s", "Please don't! That's exactly the revenge-trade trap. Take a day "
         "off the charts.", 6),
        ("tanjila_a", "Happened to me last month too. Smaller size, one setup, and the "
         "streak ended by itself.", 6),
        ("ashik_m", "Okay. Taking tomorrow off and journaling those three losses "
         "instead 📓", None),
        ("samira_h", "Tip for everyone: the journal shows which rule you break most. "
         "Mine was poor risk-reward 🙈", None),
        ("mahir_r", "We're #5 in the community ranking. Two more of us in the top 50 "
         "and we pass KUET 💪", None),
        ("nabila_s", "Challenge accepted 😄", 11),
    ],
    "cuet": [
        ("zarif_a", "Welcome aboard, CUET! Chattogram's traders — one planned trade at "
         "a time 🌊", None),
        ("maliha_c", "Hi all! Anyone else watching the London open from the library? 😄",
         None),
        ("arnab_d", "Every day at 1 pm, right after lab 😂", 1),
        ("nayeem_u", "Can someone just give me an entry for EUR/USD tonight?", None),
        ("tasfia_k", "No signals here bhai, that's the one rule 😄 Share your own idea "
         "and we'll go through it together.", 3),
        ("nayeem_u", "Fair. I'm thinking of a pullback to the daily support near the "
         "Asian range low, stop below the wick.", 4),
        ("zarif_a", "Now that's a plan. Check the reward is at least 1.5R before you "
         "take it.", 5),
        ("sumaiya_n", "Lost 1R today, but I waited for the candle to close like my plan "
         "said. Small win for me 😌", None),
        ("maliha_c", "That's the real win. The results come later.", 7),
        ("arnab_d", "Journal streak at 5 days. Didn't think I'd stick with it this long",
         None),
        ("zarif_a", "We're #2 in the ranking, right behind BUET 👀", None),
        ("tasfia_k", "Let's catch them the boring way — fewer, better trades.", 10),
        ("sumaiya_n", "Boring is the new exciting 😄", 11),
    ],
    "kuet": [
        ("rakib_h", "Welcome to the KUET community! Anchored in risk management ⚓ — 1% "
         "a trade, a journal every day.", None),
        ("lamia_i", "Nine-day journal streak and still down 11R 😅 but every rule "
         "followed.", None),
        ("fariha_t", "And the best discipline score in here. The R will follow.", 1),
        ("shafin_a", "+30R this month 😎", None),
        ("towhid_a", "Teach us, master 🙏", 3),
        ("rakib_h", "Congrats Shafin — but your discipline is at 76. Which rules are "
         "you breaking?", 3),
        ("shafin_a", "Mostly oversized trades… and a couple I never journaled. Fair "
         "point.", 5),
        ("jannatul_f", "Question: is it okay to hold a practice trade overnight?", None),
        ("fariha_t", "It's allowed, but the swap is charged just like on a real "
         "account — check it before you hold.", 7),
        ("towhid_a", "Lost 5R this week, mostly from moving stops. Fresh plan from "
         "tomorrow.", None),
        ("lamia_i", "Write the plan before the session, not during it. That's what "
         "fixed it for me.", 9),
        ("rakib_h", "We're #4 right now — a single point behind DUET 😤", None),
        ("jannatul_f", "One point! Let's go KUET 🔥", 11),
    ],
    "duet": [
        ("imtiaz_h", "Welcome to the DUET community, Gazipur gang ⚡ Quick to learn, "
         "careful to act.", None),
        ("ayesha_s", "Happy to be here! Eight days of journaling done ✅", None),
        ("nahid_h", "Took 6 trades today. Pretty sure 4 of them were boredom 😬", None),
        ("mahjabin_r", "Overtrading costs you discipline every time. Try a hard limit "
         "— two trades a day.", 2),
        ("nahid_h", "Setting the limit now. Thanks apu 🙏", 3),
        ("asif_i", "Anyone notice the prices here sit at the real market level? "
         "EUR/USD was right at this morning's ECB rate.", None),
        ("imtiaz_h", "Yes — the practice market starts each day from the ECB reference "
         "rates. The movement is simulated, the level is real.", 5),
        ("nowshin_a", "First week done. Small risk, lots of learning 🌱", None),
        ("ayesha_s", "That's the way. The leaderboard rewards the careful ones.", 7),
        ("imtiaz_h", "+24R this month with discipline around 90. Still room to "
         "improve 📈", None),
        ("asif_i", "We're #3 now, just 1 point ahead of KUET 👀", None),
        ("mahjabin_r", "Then no revenge trades this week, everyone 😄", 10),
        ("nahid_h", "Two trades a day. Promise 🤝", 11),
    ],
}


def s(v):
    return {"stringValue": str(v)}


def i(v):
    return {"integerValue": str(int(v))}


def ts(t: datetime):
    return {"timestampValue": t.strftime("%Y-%m-%dT%H:%M:%S.%fZ")}


def request(method: str, url: str, token: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        url,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={
            "authorization": f"Bearer {token}",
            "content-type": "application/json",
            # Cloudflare refuses Python's default user agent (error 1010).
            "user-agent": "forex-trading-seed",
        },
    )
    try:
        raw = urllib.request.urlopen(req).read()
        return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        return {"__error": error.code, "body": error.read().decode()[:400]}


def get(path: str, token: str) -> dict | None:
    reply = request("GET", f"{DOCS}/{path}", token)
    return None if "__error" in reply else reply


def commit(writes: list[dict], token: str) -> dict:
    return request("POST", f"{DOCS}:commit", token, {"writes": writes})


def name(path: str) -> str:
    return f"{BASE}/{path}"


# --- creating ------------------------------------------------------------------


def create_trader(index: int, row: tuple, token: str, key: str, now: datetime) -> str | None:
    username, display, gender, discipline, win, total_r, count, streak = row
    email = f"{username}@{EMAIL_DOMAIN}"

    claim = get(f"usernames/{username}", token)
    result = post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={key}",
        {"email": email, "password": PASSWORD, "returnSecureToken": True},
    )
    if "__error" in result:
        if "EMAIL_EXISTS" not in result["body"]:
            print(f"  ✗ {username}: {result['body'][:120]}")
            return None
        result = post(
            f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={key}",
            {"email": email, "password": PASSWORD, "returnSecureToken": True},
        )
        if "__error" in result:
            print(f"  ✗ {username}: exists, and not with the demo password")
            return None
    uid = result["localId"]

    # Someone else's name: never taken over.
    owner = (claim or {}).get("fields", {}).get("uid", {}).get("stringValue")
    if claim and owner != uid:
        print(f"  ✗ {username}: that username belongs to someone else")
        return None

    created = firestore_write(
        f"users/{uid}",
        {
            "username": s(username),
            "displayName": s(display),
            "nameLower": s(display.lower()),
            "gender": s(gender),
            "language": s("en"),
            "avatarId": i(AVATARS[index % len(AVATARS)]),
            "cohort": s(""),
            "createdAt": s((now - timedelta(days=60)).strftime("%Y-%m-%dT%H:%M:%S.000")),
            # The clean slate every new account starts from; the worker
            # writes the real numbers from the journal below.
            "disciplineScore": {"doubleValue": 100.0},
            "badgePoints": i(0),
            "tradeCount": i(0),
            "winRate": {"doubleValue": 0.0},
            "journalStreak": i(0),
            "totalR": {"doubleValue": 0.0},
        },
        token,
        create_only=True,
    )
    fresh = "__error" not in created
    if not fresh and "exist" not in created.get("body", "").lower():
        print(f"  ✗ {username}: profile not written — {created.get('body', '')[:120]}")
        return None
    if not claim:
        firestore_write(f"usernames/{username}", {"uid": s(uid)}, token, create_only=True)

    if fresh:
        brief = {
            "username": username,
            "tradeCount": count,
            "winRate": win,
            "journalStreak": streak,
            "totalR": total_r,
            "disciplineScore": discipline,
        }
        trades = build_trades(brief, now)
        for start in range(0, len(trades), 400):
            reply = commit(
                [
                    {
                        "update": {
                            "name": name(f"users/{uid}/trades/{t['id']}"),
                            "fields": {k: to_value(v) for k, v in t.items() if k != "id"},
                        }
                    }
                    for t in trades[start : start + 400]
                ],
                token,
            )
            if "__error" in reply:
                print(f"  ✗ {username}: trades not written — {reply['body'][:120]}")
                return uid
        _, id_token = sign_in(username, key)
        stats = recompute(id_token)
        if "error" in stats:
            print(f"  ✗ {username}: scored later — {stats}")
        else:
            print(
                f"  ✓ {display:<18} @{username:<11} {len(trades):>3} trades → "
                f"discipline {stats['disciplineScore']:5.1f}, "
                f"R {stats['totalR']:+6.1f}"
            )
        # Well inside the free tiers.
        time.sleep(0.4)
    else:
        print(f"  · {display:<18} @{username:<11} already here")
    return uid


def create_community(c: dict, members: list[tuple[str, str]], token: str, now: datetime) -> None:
    """[members] is (uid, username), the admin first. One commit: the
    community, its name, its room, and everyone in both — as the app does it."""
    cid = c["id"]
    room = f"rooms/c_{cid}"
    if get(f"communities/{cid}", token):
        print(f"  · {c['name']} — already here")
        return

    count = len(members)
    admin_uid = members[0][0]
    writes = [
        {
            "update": {
                "name": name(f"communities/{cid}"),
                "fields": {
                    "name": s(c["name"]),
                    "nameLower": s(c["name"].lower()),
                    "description": s(c["description"]),
                    "avatarId": i(c["avatar"]),
                    "createdBy": s(admin_uid),
                    "memberCount": i(count),
                },
            },
            "updateTransforms": [{"fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"}],
            "currentDocument": {"exists": False},
        },
        {
            "update": {
                "name": name(f"communityNames/{c['name'].lower()}"),
                "fields": {"communityId": s(cid)},
            },
            "currentDocument": {"exists": False},
        },
        {
            "update": {
                "name": name(room),
                "fields": {
                    "name": s(c["name"]),
                    "community": s(cid),
                    "memberCount": i(count),
                    "lastMessage": {"nullValue": None},
                },
            },
            "updateTransforms": [
                {"fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"},
                {"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"},
            ],
        },
    ]
    for n, (uid, username) in enumerate(members):
        # One after another, a few minutes apart: the admin first, then each
        # member in the order they joined.
        joined = now - timedelta(minutes=(count - n) * 7)
        writes += [
            {
                "update": {
                    "name": name(f"communities/{cid}/members/{uid}"),
                    "fields": {
                        "role": s("admin" if n == 0 else "member"),
                        "joinedAt": ts(joined),
                        "username": s(username),
                    },
                }
            },
            {
                "update": {
                    "name": name(f"{room}/members/{uid}"),
                    "fields": {"joinedAt": ts(joined), "readAt": ts(joined)},
                }
            },
            {
                "update": {"name": name(f"users/{uid}"), "fields": {"communityId": s(cid)}},
                "updateMask": {"fieldPaths": ["communityId"]},
            },
        ]
    reply = commit(writes, token)
    if "__error" in reply:
        print(f"  ✗ {c['name']}: {reply['body'][:160]}")
        return
    print(f"  ✓ {c['name']}")
    for n, (_, username) in enumerate(members):
        print(f"      {'admin ' if n == 0 else '      '}@{username}")


def create() -> None:
    token = access_token()
    key = web_api_key()
    now = datetime.now(timezone.utc)

    index = 0
    uids: dict[str, list[tuple[str, str]]] = {}
    for c in COMMUNITIES:
        print(f"\n{c['key'].upper()} — six traders")
        for row in TRADERS[c["key"]]:
            uid = create_trader(index, row, token, key, now)
            index += 1
            if uid:
                uids.setdefault(c["key"], []).append((uid, row[0]))

    print("\nCommunities")
    for c in COMMUNITIES:
        members = uids.get(c["key"], [])
        if len(members) != len(TRADERS[c["key"]]):
            print(f"  ✗ {c['name']}: not everyone is here, left for next time")
            continue
        # Nobody is put in a second community.
        taken = [
            u for uid, u in members
            if ((get(f"users/{uid}", token) or {}).get("fields", {})
                .get("communityId", {}).get("stringValue", "")) not in ("", c["id"])
        ]
        if taken:
            print(f"  ✗ {c['name']}: already in another community — {', '.join(taken)}")
            continue
        create_community(c, members, token, now)


# --- talking -------------------------------------------------------------------


def new_id() -> str:
    """A document id the way Firestore makes them: twenty letters and digits."""
    import secrets
    import string

    return "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(20))


def chat() -> None:
    """Each community's first conversation, sent by its members — each
    message as the app sends one: the message, the room's preview and the
    sender's read mark, in one write, under the sender's own sign-in."""
    token = access_token()
    key = web_api_key()
    for c in COMMUNITIES:
        room = f"rooms/c_{c['id']}"
        info = get(room, token)
        print(f"\n{c['name']}")
        if not info:
            print("  ✗ no room — run without --chat first")
            continue
        if "mapValue" in info.get("fields", {}).get("lastMessage", {}):
            print("  · already talking — left as it is")
            continue

        people: dict[str, tuple[str, str, str]] = {}
        sent: list[tuple[str, str]] = []
        for username, text, reply_to in CHATS[c["key"]]:
            if username not in people:
                uid, id_token = sign_in(username, key)
                profile = get(f"users/{uid}", token) or {}
                display = profile.get("fields", {}).get("displayName", {}).get("stringValue", "")
                people[username] = (uid, id_token, display)
            uid, id_token, display = people[username]
            mid = new_id()
            fields = {
                "senderUid": s(uid),
                "senderName": s(display),
                "senderUsername": s(username),
                "text": s(text),
                "unsent": {"booleanValue": False},
            }
            if reply_to is not None:
                rid, ruid = sent[reply_to]
                fields["replyTo"] = {"mapValue": {"fields": {"id": s(rid), "senderUid": s(ruid)}}}
            now = [{"fieldPath": "sentAt", "setToServerValue": "REQUEST_TIME"}]
            reply = commit(
                [
                    {
                        "update": {"name": name(f"{room}/messages/{mid}"), "fields": fields},
                        "updateTransforms": now,
                        "currentDocument": {"exists": False},
                    },
                    {
                        "update": {
                            "name": name(room),
                            "fields": {
                                "lastMessage": {
                                    "mapValue": {
                                        "fields": {
                                            "id": s(mid),
                                            "senderUid": s(uid),
                                            "senderName": s(display),
                                            "text": s(text),
                                            "unsent": {"booleanValue": False},
                                        }
                                    }
                                }
                            },
                        },
                        "updateMask": {"fieldPaths": ["lastMessage"]},
                        "updateTransforms": [
                            {"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"}
                        ],
                    },
                    {
                        "update": {"name": name(f"{room}/members/{uid}"), "fields": {}},
                        "updateMask": {"fieldPaths": []},
                        "updateTransforms": [
                            {"fieldPath": "readAt", "setToServerValue": "REQUEST_TIME"}
                        ],
                    },
                ],
                id_token,
            )
            if "__error" in reply:
                print(f"  ✗ @{username}: {reply['body'][:160]}")
                break
            sent.append((mid, uid))
            arrow = f"↳ {CHATS[c['key']][reply_to][0]}: " if reply_to is not None else ""
            print(f"  {display:<17} {arrow}{text[:60]}{'…' if len(text) > 60 else ''}")
            # A conversation, not a burst.
            time.sleep(1.5)


# --- removing ------------------------------------------------------------------


def remove() -> None:
    token = access_token()
    key = web_api_key()
    print("Accounts")
    for c in COMMUNITIES:
        for row in TRADERS[c["key"]]:
            username = row[0]
            reply = post(
                f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={key}",
                {"email": f"{username}@{EMAIL_DOMAIN}", "password": PASSWORD,
                 "returnSecureToken": True},
            )
            if "__error" in reply:
                print(f"  · @{username} — not here")
                continue
            id_token = reply["idToken"]
            # The worker erases in rounds when there is a lot; ask until done.
            for _ in range(10):
                done = request("POST", f"{WORKER}/delete-account", id_token)
                if done.get("done"):
                    break
            else:
                print(f"  ✗ @{username}: the worker did not finish")
                continue
            post(f"https://identitytoolkit.googleapis.com/v1/accounts:delete?key={key}",
                 {"idToken": id_token})
            # Demo names go back to being free, unlike a real account's.
            commit([{"delete": name(f"usernames/{username}")}], token)
            print(f"  ✓ @{username}")

    print("\nCommunities")
    for c in COMMUNITIES:
        cid = c["id"]
        room = f"rooms/c_{cid}"
        below = []
        for parent, collection in [(f"communities/{cid}", "members"), (room, "members"),
                                   (room, "messages")]:
            listing = request("GET", f"{DOCS}/{parent}/{collection}?pageSize=300", token)
            below += [{"delete": d["name"]} for d in listing.get("documents", [])]
        reply = commit(
            below + [
                {"delete": name(f"communities/{cid}")},
                {"delete": name(f"communityNames/{c['name'].lower()}")},
                {"delete": name(room)},
            ],
            token,
        )
        print(f"  {'✗' if '__error' in reply else '✓'} {c['name']}")


if __name__ == "__main__":
    if "--remove" in sys.argv:
        remove()
    elif "--chat" in sys.argv:
        chat()
    else:
        create()
