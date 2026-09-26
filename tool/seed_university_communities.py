#!/usr/bin/env python3
"""Five university communities, and thirty demo traders to fill them.

    python3 tool/seed_university_communities.py           # create what is missing
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
    remove() if "--remove" in sys.argv else create()
