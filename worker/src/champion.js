// The month's champion: the community on top of the rankings when the month
// turns, in Dhaka. Decided once, on the first morning of the next month, and
// kept — on the community, as a title, and under champions/ by month.
//
// Points are the app's (app/lib/models/community.dart, communityPoints): a
// member at #1 of the top fifty is worth 50, at #50 worth 1. Ties go to the
// bigger community, then the name, as the app ranks them.

const DHAKA_OFFSET_MS = 6 * 60 * 60 * 1000;
const TOP = 50;

/** The month before the Dhaka day [ms] falls on, "2026-09" — and that day. */
export function monthJustEnded(ms) {
  const d = new Date(ms + DHAKA_OFFSET_MS);
  const prev = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - 1, 1));
  return {
    month: `${prev.getUTCFullYear()}-${String(prev.getUTCMonth() + 1).padStart(2, '0')}`,
    day: d.getUTCDate(),
  };
}

/** Each community's points from [board], best first. */
export function communityPoints(board) {
  const points = new Map();
  board.slice(0, TOP).forEach((t, i) => {
    const id = t.communityId;
    if (typeof id !== 'string' || id === '') return;
    points.set(id, (points.get(id) ?? 0) + (TOP - i));
  });
  return points;
}

/** The ranked board: by discipline, then by trades, as the app orders it. */
export function rankedBoard(users) {
  return [...users].sort(
    (a, b) => (b.disciplineScore ?? 0) - (a.disciplineScore ?? 0) || (b.tradeCount ?? 0) - (a.tradeCount ?? 0),
  );
}

/** The top community, or null when nobody in any has points. */
export function topCommunity(communities, points) {
  const ranked = communities
    .map((c) => ({ ...c, points: points.get(c.id) ?? 0 }))
    .sort(
      (a, b) =>
        b.points - a.points ||
        (b.memberCount ?? 0) - (a.memberCount ?? 0) ||
        (a.name ?? '').toLowerCase().localeCompare((b.name ?? '').toLowerCase()),
    );
  return ranked[0]?.points > 0 ? ranked[0] : null;
}

/**
 * Crowns last month's champion, if it is early in the month and nobody has
 * yet. Returns what was decided, or why nothing was.
 */
export async function crownChampion(store, now = Date.now()) {
  const { month, day } = monthJustEnded(now);
  // The first three mornings, in case one run fails.
  if (day > 3) return { skipped: 'not the start of a month' };
  if (await store.get(`champions/${month}`)) return { skipped: 'already crowned' };

  const users = await store.find({
    collection: 'users',
    field: 'ranked',
    value: true,
    limit: 500,
    fields: ['disciplineScore', 'tradeCount', 'communityId'],
  });
  const points = communityPoints(rankedBoard(users.map((u) => u.data)));
  const communities = await store.find({
    collection: 'communities',
    limit: 500,
    fields: ['name', 'memberCount', 'titles'],
  });
  const top = topCommunity(
    communities.map((c) => ({ id: c.path.split('/')[1], ...c.data })),
    points,
  );

  const writes = [
    {
      create: `champions/${month}`,
      fields: { month, communityId: top?.id ?? '', name: top?.name ?? '', points: top?.points ?? 0 },
    },
  ];
  if (top) {
    const titles = Array.isArray(top.titles) ? top.titles : [];
    if (!titles.includes(month)) {
      writes.push({ set: `communities/${top.id}`, field: 'titles', value: [...titles, month] });
    }
  }
  await store.commit(writes);
  return { month, communityId: top?.id ?? '', points: top?.points ?? 0 };
}
