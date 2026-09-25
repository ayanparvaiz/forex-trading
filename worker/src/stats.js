// The leaderboard formula, in JavaScript.
//
// A mirror of app/lib/core/leaderboard_stats.dart and the parts of
// calculations.dart, trade.dart and instrument.dart it depends on. Both
// implementations are tested against tool/stats_fixture.json, so they cannot
// drift apart without a test failing. If you change a number here, change it
// there too, regenerate the fixture from Dart, and run both suites.

/** Mirrors Instrument in app/lib/models/instrument.dart. */
export const INSTRUMENTS = {
  'EUR/USD': { pipSize: 0.0001, spreadPips: 0.8, pipValuePerLot: 10, swapLong: -7.2, swapShort: 2.1 },
  'GBP/USD': { pipSize: 0.0001, spreadPips: 1.3, pipValuePerLot: 10, swapLong: -6.4, swapShort: 1.2 },
  'USD/JPY': { pipSize: 0.01, spreadPips: 1.0, pipValuePerLot: 6.7, swapLong: 4.8, swapShort: -11.3 },
};

/** Mirrors RuleViolation.weight in app/lib/models/trade.dart. */
export const VIOLATION_WEIGHTS = {
  riskTooHigh: 30,
  noReason: 15,
  poorRiskReward: 15,
  movedStop: 35,
  revengeTrade: 25,
  overtrading: 20,
  noJournal: 10,
};

/**
 * Closed trades needed before an account appears on the leaderboard.
 *
 * With no closed trades the discipline score is 100 — nothing has been broken
 * yet — so without a floor every brand-new account would sit at the top,
 * above people who have kept their rules over dozens of trades. Mirrors
 * CommunityRepository.minRankedTrades in the app.
 */
export const MIN_RANKED_TRADES = 5;

const DAY_MS = 24 * 60 * 60 * 1000;

// Bangladesh time, fixed at UTC+6 with no daylight saving. The app counts
// days the same way, so a streak is the same number on the phone and on the
// leaderboard.
const DHAKA_OFFSET_MS = 6 * 60 * 60 * 1000;

// Unknown symbols fall back to EUR/USD, as Instrument.bySymbol does.
const instrumentOf = (symbol) => INSTRUMENTS[symbol] ?? INSTRUMENTS['EUR/USD'];

// Unknown violation names are dropped, as Trade.fromJson does: a flag renamed
// in a later version should cost that one flag, not the whole journal.
const knownViolations = (list) =>
  [...new Set(list ?? [])].filter((v) => v in VIOLATION_WEIGHTS);

const time = (iso) => (iso == null ? null : Date.parse(iso));

/** Net result in account currency: gross minus spread plus swap. */
export function realisedPnl(trade) {
  if (trade.exitPrice == null) return null;
  const inst = instrumentOf(trade.symbol);
  const sign = trade.direction === 'sell' ? -1 : 1;

  const gross = ((trade.exitPrice - trade.entryPrice) * sign) / inst.pipSize
    * inst.pipValuePerLot * trade.lots;
  const spread = inst.spreadPips * inst.pipValuePerLot * trade.lots;

  // Whole nights held, truncated — Duration.inDays.
  const closed = time(trade.closedAt) ?? Date.now();
  const nights = Math.floor((closed - time(trade.openedAt)) / DAY_MS);
  const perNight = sign === 1 ? inst.swapLong : inst.swapShort;
  const swap = nights <= 0 ? 0 : perNight * trade.lots * nights;

  return gross - spread + swap;
}

/** Result in R, or null when it cannot be expressed as one. */
export function rMultiple(trade) {
  const pnl = realisedPnl(trade);
  const inst = instrumentOf(trade.symbol);
  const riskPips = Math.abs(trade.entryPrice - trade.stopPrice) / inst.pipSize;
  const riskAmount = riskPips * inst.pipValuePerLot * trade.lots;
  if (pnl == null || riskAmount === 0) return null;
  return pnl / riskAmount;
}

const dayOf = (ms) => Math.floor((ms + DHAKA_OFFSET_MS) / DAY_MS);

function journalStreak(closed, nowMs) {
  const days = new Set(
    closed
      .filter((t) => (t.lesson ?? '').trim() !== '')
      .map((t) => dayOf(time(t.closedAt))),
  );
  if (days.size === 0) return 0;

  const today = dayOf(nowMs);
  // Yesterday still counts, so a streak does not break at midnight just
  // because today's trade has not been journaled yet.
  let day = days.has(today) ? today : today - 1;
  if (!days.has(day)) return 0;

  let streak = 0;
  while (days.has(day)) {
    streak++;
    day--;
  }
  return streak;
}

/**
 * The six numbers a leaderboard row shows.
 *
 * Mirrors LeaderboardStats.from. Only closed trades count: an open position
 * has no result yet, and a score that moved with the live price would reward
 * whoever looked at the right moment.
 */
export function leaderboardStats(trades, now = new Date()) {
  const nowMs = now instanceof Date ? now.getTime() : Date.parse(now);

  const closed = trades
    .filter((t) => t.closedAt != null)
    // Same order as TradeStats.from, so floating-point sums add up in the
    // same sequence on both sides.
    .sort((a, b) => time(a.closedAt) - time(b.closedAt));

  if (closed.length === 0) {
    return {
      disciplineScore: 100,
      badgePoints: 0,
      tradeCount: 0,
      totalR: 0,
      winRate: 0,
      journalStreak: 0,
    };
  }

  let discipline = 0;
  let badge = 0;
  let totalR = 0;
  let wins = 0;

  for (const t of closed) {
    const penalty = knownViolations(t.violations)
      .reduce((sum, v) => sum + VIOLATION_WEIGHTS[v], 0);
    discipline += Math.max(0, 100 - penalty);

    badge += (realisedPnl(t) ?? 0) > 0 ? 1 : -1;

    const r = rMultiple(t) ?? 0;
    totalR += r;
    if (r > 0) wins++;
  }

  return {
    disciplineScore: discipline / closed.length,
    badgePoints: badge,
    tradeCount: closed.length,
    totalR,
    winRate: wins / closed.length,
    journalStreak: journalStreak(closed, nowMs),
  };
}
