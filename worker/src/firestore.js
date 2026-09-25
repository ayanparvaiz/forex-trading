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

// --- Erasing an account ------------------------------------------------------

/**
 * Thrown when a call should simply be made again: this request has used up
 * its share of Firestore calls, or a document changed under a write. Erasing
 * is written so that running it again picks up where it stopped.
 */
export class TryAgain extends Error {}

function encodeValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Number.isInteger(v)) return { integerValue: String(v) };
  if (typeof v === 'number') return { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encodeValue) } };
  return {
    mapValue: {
      fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encodeValue(x)])),
    },
  };
}

const OPS = { '==': 'EQUAL', 'array-contains': 'ARRAY_CONTAINS' };

/**
 * The few Firestore calls erasing needs, over REST, each one counted.
 *
 * Paths are relative to the database root ("users/abc/trades/t1"). [budget]
 * caps the calls one request makes: Cloudflare's free plan allows 50
 * outgoing requests per incoming one, and token checks need some of those.
 * Past the budget every call throws TryAgain, and the app asks again.
 */
export function restStore(projectId, token, { budget = 40 } = {}) {
  const root = `projects/${projectId}/databases/(default)/documents`;
  const api = `https://firestore.googleapis.com/v1/${root}`;
  const url = (path) => (path ? `${api}/${path.split('/').map(encodeURIComponent).join('/')}` : api);
  const full = (path) => `${root}/${path}`;
  const relative = (name) => name.slice(root.length + 1);
  let spent = 0;

  async function call(target, body, { commit = false } = {}) {
    if (spent >= budget) throw new TryAgain('out of budget');
    spent++;
    const res = await fetch(target, {
      method: body ? 'POST' : 'GET',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: body && JSON.stringify(body),
    });
    if (res.status === 404 && !body) return null;
    if (!res.ok) {
      const text = await res.text();
      // A write whose precondition no longer holds — a post deleted between
      // reading its count and writing it. Nothing is written; the next call
      // re-reads. Only for commits: a query refused for a missing index says
      // FAILED_PRECONDITION too, and asking again would never fix that.
      if (commit && (res.status === 409 || text.includes('FAILED_PRECONDITION'))) {
        throw new TryAgain(`conflict: ${text}`);
      }
      throw new Error(`firestore ${res.status}: ${text}`);
    }
    return res.json();
  }

  const select = (fields) => ({
    fields: (fields.length ? fields : ['__name__']).map((fieldPath) => ({ fieldPath })),
  });

  async function runQuery(parent, structuredQuery) {
    const rows = await call(`${url(parent)}:runQuery`, { structuredQuery });
    return rows
      .filter((r) => r.document)
      .map((r) => ({ path: relative(r.document.name), data: decodeFields(r.document.fields ?? {}) }));
  }

  return {
    get spent() {
      return spent;
    },

    /** One document's [fields], or null if it does not exist. */
    async get(path, fields = []) {
      const target = new URL(url(path));
      for (const f of fields) target.searchParams.append('mask.fieldPaths', f);
      const doc = await call(target);
      return doc ? decodeFields(doc.fields ?? {}) : null;
    },

    /**
     * Documents in [collection] whose [field] matches, by path. With [group],
     * every collection of that name at any depth; with [parent], the
     * collection under that document.
     */
    find({ parent = '', collection, group = false, field, op = '==', value, limit, fields = [] }) {
      return runQuery(parent, {
        from: [{ collectionId: collection, allDescendants: group }],
        where: { fieldFilter: { field: { fieldPath: field }, op: OPS[op], value: encodeValue(value) } },
        select: select(fields),
        limit,
      });
    },

    /** The document in [parent]/[collection] with the highest [field], or null. */
    async newest(parent, collection, field, fields = []) {
      const rows = await runQuery(parent, {
        from: [{ collectionId: collection }],
        orderBy: [{ field: { fieldPath: field }, direction: 'DESCENDING' }],
        select: select(fields),
        limit: 1,
      });
      return rows[0] ?? null;
    },

    /** Paths of every document below [path], in any subcollection. */
    async descendants(path, limit) {
      const rows = await runQuery(path, {
        from: [{ allDescendants: true }],
        select: select([]),
        limit,
      });
      return rows.map((r) => r.path);
    },

    /** Several documents at once: path → fields, or null where missing. */
    async getAll(paths, fields = []) {
      const out = new Map();
      if (paths.length === 0) return out;
      const body = { documents: paths.map(full) };
      if (fields.length) body.mask = { fieldPaths: fields };
      for (const r of await call(`${api}:batchGet`, body)) {
        if (r.found) out.set(relative(r.found.name), decodeFields(r.found.fields ?? {}));
        else out.set(relative(r.missing), null);
      }
      return out;
    },

    /**
     * Applies [writes] atomically — all of them or none.
     *
     *   { delete: path }
     *   { increment: path, field, by }   the document must still exist
     *   { set: path, field, value }      the document must still exist
     *   { replace: path, serverTime }    the whole document becomes one timestamp
     */
    async commit(writes) {
      const rest = writes.map((w) => {
        if (w.delete) return { delete: full(w.delete) };
        if (w.increment) {
          return {
            transform: {
              document: full(w.increment),
              fieldTransforms: [{ fieldPath: w.field, increment: encodeValue(w.by) }],
            },
            currentDocument: { exists: true },
          };
        }
        if (w.set) {
          return {
            update: { name: full(w.set), fields: { [w.field]: encodeValue(w.value) } },
            updateMask: { fieldPaths: [w.field] },
            currentDocument: { exists: true },
          };
        }
        if (w.replace) {
          return {
            update: { name: full(w.replace), fields: {} },
            updateTransforms: [{ fieldPath: w.serverTime, setToServerValue: 'REQUEST_TIME' }],
          };
        }
        throw new Error(`unknown write ${JSON.stringify(w)}`);
      });
      await call(`${api}:commit`, { writes: rest }, { commit: true });
    },
  };
}
