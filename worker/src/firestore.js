// Firestore over REST.
//
// The REST API wraps every value in a type tag — {"doubleValue": 1.08} — so
// reading a trade means unwrapping, and writing a score means wrapping. Both
// directions live here so nothing else in the worker has to know.

const base = (projectId) =>
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

/** Unwraps one Firestore REST value into plain JSON. */
export function decodeValue(v) {
  if (v == null || 'nullValue' in v) return null;
  if ('booleanValue' in v) return v.booleanValue;
  // Integers arrive as strings so 64-bit values survive JSON. Trade fields are
  // far below 2^53, so Number() loses nothing here.
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('stringValue' in v) return v.stringValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(decodeValue);
  if ('mapValue' in v) return decodeFields(v.mapValue.fields ?? {});
  return null;
}

export function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [k, decodeValue(v)]),
  );
}

/**
 * Every trade the account has, up to [cap].
 *
 * The cap bounds what one recompute can cost. It matches the app, which loads
 * the most recent 500 — so the leaderboard and the journal are computed over
 * the same trades rather than two different windows.
 */
export async function listTrades(projectId, uid, token, cap = 500) {
  const trades = [];
  let pageToken = '';

  do {
    const url = new URL(`${base(projectId)}/users/${encodeURIComponent(uid)}/trades`);
    url.searchParams.set('pageSize', '300');
    url.searchParams.set('orderBy', 'openedAt desc');
    if (pageToken) url.searchParams.set('pageToken', pageToken);

    const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`list trades ${res.status}: ${await res.text()}`);

    const body = await res.json();
    for (const doc of body.documents ?? []) {
      trades.push({ id: doc.name.split('/').pop(), ...decodeFields(doc.fields ?? {}) });
    }
    pageToken = body.nextPageToken ?? '';
  } while (pageToken && trades.length < cap);

  return trades.slice(0, cap);
}

/** When this account's scores were last written, or null if never. */
export async function statsUpdatedAt(projectId, uid, token) {
  const url = new URL(`${base(projectId)}/users/${encodeURIComponent(uid)}`);
  url.searchParams.append('mask.fieldPaths', 'statsUpdatedAt');

  const res = await fetch(url, { headers: { authorization: `Bearer ${token}` } });
  if (res.status === 404) throw new Error('no such user');
  if (!res.ok) throw new Error(`read user ${res.status}: ${await res.text()}`);

  const ts = (await res.json()).fields?.statsUpdatedAt?.timestampValue;
  return ts ? Date.parse(ts) : null;
}

// Counts are written as integers and everything else as doubles, so the
// document reads the same whether a number happens to be whole or not — a
// discipline score of exactly 100 is still a double.
const INTEGER_FIELDS = new Set(['badgePoints', 'tradeCount', 'journalStreak']);

/**
 * Writes the score fields, and only those.
 *
 * The update mask means nothing else on the profile is touched, and
 * currentDocument.exists means a token for a user with no profile cannot
 * conjure one into existence.
 */
export async function writeStats(projectId, uid, stats, token, now = new Date()) {
  const fields = {};
  for (const [k, v] of Object.entries(stats)) {
    if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    else if (INTEGER_FIELDS.has(k)) fields[k] = { integerValue: String(Math.trunc(v)) };
    else fields[k] = { doubleValue: v };
  }
  fields.statsUpdatedAt = { timestampValue: now.toISOString() };

  const url = new URL(`${base(projectId)}/users/${encodeURIComponent(uid)}`);
  for (const k of Object.keys(fields)) url.searchParams.append('updateMask.fieldPaths', k);
  url.searchParams.set('currentDocument.exists', 'true');

  const res = await fetch(url, {
    method: 'PATCH',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) throw new Error(`write stats ${res.status}: ${await res.text()}`);
}
