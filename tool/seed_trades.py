#!/usr/bin/env python3
"""Gives the demo accounts real trade histories, then lets the worker score them.

    python3 tool/seed_trades.py            # write trades, then recompute
    python3 tool/seed_trades.py --dry-run  # print what would be written
    python3 tool/seed_trades.py --recompute-only  # just ask the worker again

Before this, the demo accounts' leaderboard numbers were typed into their
profiles by hand, with no trades behind them — and they did not even agree
with each other: one account showed a badge of 214 from 196 trades at a 49%
win rate, which nets out to about minus four. They were mock data sitting in
the real database.

This writes each demo account a journal of closed trades shaped by the
character the account was meant to have — clean and patient, or profitable
and reckless — and then asks the stats worker to recompute each account's row
from those trades, through the same endpoint the app uses. What the
leaderboard shows afterwards is whatever the trades produce. The profile
numbers in seed_accounts.dart are only used as a brief for generating the
trades, never as the answer.

The owner's account is not given trades. Its journal is the real one, and
it is only recomputed from whatever is already in it.

Deterministic: each account's trades come from a random generator seeded
with its username, and trade ids are fixed, so running this again rewrites
the same documents instead of adding more.
"""

from __future__ import annotations

import json
import random
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

from seed_firestore import (
    EMAIL_DOMAIN,
    PROJECT,
    access_token,
    parse_seed_accounts,
    web_api_key,
)

OWNER = "ayan"
PASSWORD = "demo1234"
WORKER = "https://forex-trading-stats.forex-trading-stats.workers.dev/recompute"

# Mirrors app/lib/models/instrument.dart.
INSTRUMENTS = {
    "EUR/USD": dict(base=1.08500, pip=0.0001, pip_value=10.0),
    "GBP/USD": dict(base=1.26500, pip=0.0001, pip_value=10.0),
    "USD/JPY": dict(base=150.500, pip=0.01, pip_value=6.7),
}

# Mirrors RuleViolation.weight in app/lib/models/trade.dart — minus noReason.
# The app refuses to place a trade whose reason is under ten characters, and
# the Firestore rule refuses to store one, so no real trade can carry that
# flag. A demo journal should only contain trades the app could have made.
WEIGHTS = {
    "riskTooHigh": 30,
    "poorRiskReward": 15,
    "movedStop": 35,
    "revengeTrade": 25,
    "overtrading": 20,
    "noJournal": 10,
}

REASONS = [
    "H4 সাপোর্টে বুলিশ এনগাল্ফিং, লন্ডন সেশনের শুরুতে",
    "ডেইলি রেঞ্জের উপরে ব্রেকআউট, রিটেস্টের পর এন্ট্রি",
    "Rejected the daily high twice, sold the second rejection",
    "ট্রেন্ডলাইন বাউন্স, আগের তিনবারই এখান থেকে ঘুরেছে",
    "NY open momentum after the CPI print",
    "ডাবল বটম, নেকলাইন ব্রেক হয়েছে",
    "Pullback to the 50 EMA in a clean uptrend",
    "এশিয়ান রেঞ্জের নিচে ফেক ব্রেক, আবার ভেতরে ঢুকেছে",
]

LESSONS = [
    "প্ল্যান মেনেছি, ফল যাই হোক।",
    "Waited for the candle to close. Worth it.",
    "স্টপ ঠিক জায়গায় ছিল — মার্কেট আমার বিপক্ষে গেছে, এটাই।",
    "Entered too early; the retest came an hour later.",
    "নিউজের আগে ঢোকা ঠিক হয়নি।",
    "Size was right. That is the only thing I controlled.",
    "টার্গেটে পৌঁছানোর আগে বের হওয়ার লোভ সামলেছি।",
    "Moved on after the loss instead of chasing it.",
]


def build_trades(account: dict, now: datetime) -> list[dict]:
    """A closed-trade journal shaped by the account's intended profile."""
    rng = random.Random(f"trades:{account['username']}")
    count = int(account["tradeCount"])
    win_rate = float(account["winRate"])
    streak = int(account["journalStreak"])

    # Average winner that, with ~-1.05R losers, lands near the intended total.
    # Clamped, because a few profiles would otherwise need absurd winners.
    target_expectancy = float(account["totalR"]) / max(count, 1)
    avg_win = (target_expectancy + (1 - win_rate) * 1.05) / max(win_rate, 0.05)
    avg_win = min(max(avg_win, 0.8), 4.0)

    # Each rule is broken independently with the same probability, sized so
    # the expected penalty per trade matches the intended discipline score.
    penalty = max(0.0, 100.0 - float(account["disciplineScore"]))
    p_break = min(penalty / sum(WEIGHTS.values()), 0.9)

    # The last `streak` days get one journaled trade each, ending yesterday or
    # today; everything else is spread over the weeks before. An account meant
    # to have no streak finishes its history three days ago.
    days_back = max(count // 2, streak + 5, 20)
    recent = min(streak, count)
    older = count - recent
    end_offset = 0 if streak > 0 else 3

    trades = []
    for n in range(count):
        if n < recent:
            day = end_offset + n
        else:
            day = end_offset + recent + 1 + rng.randrange(max(days_back - recent, 1))
        streak_day = n < recent
        # Streak trades open between 08:00 and 14:00 Dhaka and close within
        # three hours, so each lands on its own day. A long hold would carry
        # the close into the next day, leave a day empty, and break the very
        # streak it was meant to build.
        opened = (now - timedelta(days=day)).replace(
            hour=rng.randrange(2, 8) if streak_day else rng.randrange(2, 16),
            minute=rng.randrange(60),
            second=0,
            microsecond=0,
        )
        # Keep today's trades in the past.
        if opened > now - timedelta(hours=3):
            opened = now - timedelta(hours=3 + rng.random() * 2)
        held = timedelta(
            hours=rng.choice([1, 2, 3]) if streak_day else rng.choice([1, 2, 3, 5, 8, 20, 30])
        )
        closed = min(opened + held, now - timedelta(minutes=5))

        symbol = rng.choice(list(INSTRUMENTS))
        inst = INSTRUMENTS[symbol]
        direction = rng.choice(["buy", "sell"])
        sign = 1 if direction == "buy" else -1

        entry = round(inst["base"] * (1 + rng.uniform(-0.01, 0.01)), 5)
        stop_pips = rng.randint(15, 35)
        stop = entry - sign * stop_pips * inst["pip"]
        violations = [v for v in WEIGHTS if rng.random() < p_break]

        # A flag has to be true of the trade it is on: poor risk-reward means
        # a target under 1.5R, which is what the app checks.
        reward_ratio = round(
            rng.uniform(1.0, 1.4) if "poorRiskReward" in violations else rng.uniform(1.5, 2.8),
            1,
        )
        target = entry + sign * stop_pips * reward_ratio * inst["pip"]
        # Journaled streak days must actually be journaled.
        if n < recent and "noJournal" in violations:
            violations.remove("noJournal")

        # Risk is ~1% of the 10,000 allowance; breaking the risk rule means
        # sizing up, which is what makes it a violation and not a label.
        # Clean trades stay under 1% after rounding, or the app would have
        # flagged them too.
        risk = 250.0 if "riskTooHigh" in violations else 95.0
        lots = max(int(risk / (stop_pips * inst["pip_value"]) * 100) / 100, 0.01)

        won = rng.random() < win_rate
        if won:
            r = max(rng.gauss(avg_win, avg_win * 0.35), 0.3)
            exit_price = entry + sign * stop_pips * r * inst["pip"]
            exit_reason = "takeProfit" if abs(r - reward_ratio) < 0.25 else "manual"
        else:
            exit_price = stop
            exit_reason = "stopLoss"

        journaled = "noJournal" not in violations
        trades.append(
            {
                "id": f"seed-{account['username']}-{n:04d}",
                "symbol": symbol,
                "direction": direction,
                "lots": lots,
                "entryPrice": entry,
                "stopPrice": round(stop, 5),
                "targetPrice": round(target, 5),
                "openedAt": opened.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                "closedAt": closed.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                "exitPrice": round(exit_price, 5),
                "exitReason": exit_reason,
                "balanceAtEntry": 10000.0,
                "reason": rng.choice(REASONS),
                "lesson": rng.choice(LESSONS) if journaled else None,
                "violations": violations,
                "isShared": False,
            }
        )
    return trades


def to_value(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [to_value(x) for x in v]}}
    raise TypeError(type(v))


def commit(writes: list[dict], token: str) -> None:
    url = (
        f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
        "/databases/(default)/documents:commit"
    )
    for start in range(0, len(writes), 400):
        body = json.dumps({"writes": writes[start : start + 400]}).encode()
        request = urllib.request.Request(
            url,
            data=body,
            headers={"authorization": f"Bearer {token}", "content-type": "application/json"},
        )
        urllib.request.urlopen(request).read()


def sign_in(username: str, key: str) -> tuple[str, str]:
    body = json.dumps(
        {"email": f"{username}@{EMAIL_DOMAIN}", "password": PASSWORD, "returnSecureToken": True}
    ).encode()
    request = urllib.request.Request(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={key}",
        data=body,
        headers={"content-type": "application/json"},
    )
    reply = json.load(urllib.request.urlopen(request))
    return reply["localId"], reply["idToken"]


def recompute(id_token: str) -> dict:
    request = urllib.request.Request(
        WORKER,
        method="POST",
        # Cloudflare refuses Python's default "Python-urllib" user agent with
        # error 1010, before the request ever reaches the worker.
        headers={"authorization": f"Bearer {id_token}", "user-agent": "forex-trading-seed"},
    )
    try:
        return json.load(urllib.request.urlopen(request))
    except urllib.error.HTTPError as error:
        return {"error": error.code, "body": error.read().decode()}


def main() -> None:
    dry = "--dry-run" in sys.argv
    recompute_only = "--recompute-only" in sys.argv
    now = datetime.now(timezone.utc)
    accounts = parse_seed_accounts()
    key = web_api_key()
    token = None if dry else access_token()

    base = f"projects/{PROJECT}/databases/(default)/documents"
    total = 0

    for account in accounts:
        username = account["username"]
        uid, id_token = sign_in(username, key)

        if username == OWNER:
            print(f"  · {username:<9} real account — trades left alone")
        elif recompute_only:
            print(f"  · {username:<9}")
        else:
            trades = build_trades(account, now)
            total += len(trades)
            if not dry:
                commit(
                    [
                        {
                            "update": {
                                "name": f"{base}/users/{uid}/trades/{t['id']}",
                                "fields": {k: to_value(v) for k, v in t.items() if k != "id"},
                            }
                        }
                        for t in trades
                    ],
                    token,
                )
            print(f"  ✓ {username:<9} {len(trades):>4} trades")

        if not dry:
            stats = recompute(id_token)
            if "error" in stats:
                print(f"    ✗ recompute failed: {stats}")
            else:
                print(
                    f"    → discipline {stats['disciplineScore']:5.1f}  "
                    f"trades {stats['tradeCount']:>3}  "
                    f"R {stats['totalR']:+7.1f}  "
                    f"win {stats['winRate'] * 100:4.0f}%  "
                    f"badge {stats['badgePoints']:+4d}  "
                    f"streak {stats['journalStreak']}"
                )
            # Stay well inside the free tiers.
            time.sleep(0.5)

    print(f"\n{total} trades {'would be' if dry else ''} written.")


if __name__ == "__main__":
    main()
