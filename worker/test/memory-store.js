// The same calls as restStore (src/firestore.js), over a Map of path →
// fields, for testing what the worker does without a network.

import assert from 'node:assert/strict';

import { TryAgain } from '../src/firestore.js';

const asNumber = (v) => (v instanceof Date ? v.getTime() : typeof v === 'string' ? Date.parse(v) : v);

export function memoryStore(docs, { budget = Infinity } = {}) {
  let spent = 0;
  const spend = () => {
    if (spent >= budget) throw new TryAgain('out of budget');
    spent++;
  };
  const sorted = () => [...docs.keys()].sort();
  const pick = (data, fields) =>
    fields.length ? Object.fromEntries(fields.filter((f) => f in data).map((f) => [f, data[f]])) : {};
  const matches = (v, op, value) => {
    switch (op) {
      case 'array-contains':
        return Array.isArray(v) && v.includes(value);
      case 'in':
        return value.includes(v);
      case '<':
        return asNumber(v) < asNumber(value);
      default:
        return v === value;
    }
  };

  return {
    get spent() {
      return spent;
    },
    async get(path, fields = []) {
      spend();
      return docs.has(path) ? pick(docs.get(path), fields) : null;
    },
    async find({ parent = '', collection, group = false, field, op = '==', value, limit, fields = [] }) {
      spend();
      const depth = parent ? parent.split('/').length + 2 : 2;
      return sorted()
        .filter((p) => {
          const parts = p.split('/');
          if (group) return parts.at(-2) === collection;
          if (parent && !p.startsWith(`${parent}/`)) return false;
          return parts.length === depth && parts.at(-2) === collection;
        })
        .filter((p) => !field || matches(docs.get(p)[field], op, value))
        .slice(0, limit)
        .map((p) => ({ path: p, data: pick(docs.get(p), fields) }));
    },
    async newest(parent, collection, field) {
      spend();
      const depth = parent.split('/').length + 2;
      const rows = sorted()
        .filter((p) => p.startsWith(`${parent}/${collection}/`) && p.split('/').length === depth)
        .sort((a, b) => (docs.get(b)[field] ?? 0) - (docs.get(a)[field] ?? 0));
      return rows.length ? { path: rows[0], data: { ...docs.get(rows[0]) } } : null;
    },
    async descendants(path, limit) {
      spend();
      return sorted().filter((p) => p.startsWith(`${path}/`)).slice(0, limit);
    },
    async getAll(paths, fields = []) {
      spend();
      return new Map(paths.map((p) => [p, docs.has(p) ? pick(docs.get(p), fields) : null]));
    },
    async commit(writes) {
      spend();
      assert.ok(writes.length <= 500, 'more than 500 writes in one commit');
      // All or nothing, like Firestore: check every precondition first.
      for (const w of writes) {
        const target = w.increment ?? w.set;
        if (target && !docs.has(target)) throw new TryAgain('precondition');
        if (w.create && docs.has(w.create)) throw new TryAgain('already exists');
      }
      for (const w of writes) {
        if (w.delete) docs.delete(w.delete);
        else if (w.increment) {
          const d = docs.get(w.increment);
          d[w.field] = (d[w.field] ?? 0) + w.by;
        } else if (w.set) docs.get(w.set)[w.field] = structuredClone(w.value);
        else if (w.replace) docs.set(w.replace, { [w.serverTime]: 'SERVER_TIME' });
        else if (w.create) docs.set(w.create, { ...w.fields });
      }
    },
  };
}
