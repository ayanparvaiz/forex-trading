// Deleting many documents a page at a time, within Firestore's limits.
// Shared by deleting an account (erase.js) and deleting a community
// (community.js).

/** Rows per query. */
export const PAGE = 300;

// Posts and chats are fetched a few at a time: each one costs a further
// query for what is under it.
export const PARENTS = 25;

/** Firestore takes at most 500 writes in one commit. */
export class WriteQueue {
  constructor(store, max = 500) {
    this.store = store;
    this.max = max;
    this.pending = [];
  }

  /** Writes that land in the same commit or not at all. */
  async add(...group) {
    if (this.pending.length + group.length > this.max) await this.flush();
    this.pending.push(...group);
  }

  async flush() {
    if (this.pending.length === 0) return;
    const writes = this.pending;
    this.pending = [];
    await this.store.commit(writes);
  }
}

export const parentOf = (path) => path.split('/').slice(0, -2).join('/');

/**
 * Deletes every document matching [query], a page at a time.
 *
 * Each page is committed before the next is asked for — otherwise the next
 * query would return the same documents again.
 */
export async function eraseMatching(store, writes, query, keep = () => true) {
  for (;;) {
    const rows = await store.find({ ...query, limit: PAGE });
    const doomed = rows.filter(keep);
    for (const r of doomed) await writes.add({ delete: r.path });
    await writes.flush();
    // A full page that deleted nothing would be the same page next time.
    if (rows.length < PAGE || doomed.length === 0) return;
  }
}

/** Deletes everything below [path] — not [path] itself. */
export async function eraseBelow(store, writes, path) {
  for (;;) {
    const paths = await store.descendants(path, PAGE);
    for (const p of paths) await writes.add({ delete: p });
    await writes.flush();
    if (paths.length < PAGE) return;
  }
}

/** Documents with things under them: the things first, then the document. */
export async function eraseParents(store, writes, query) {
  for (;;) {
    const rows = await store.find({ ...query, limit: PARENTS });
    for (const r of rows) {
      await eraseBelow(store, writes, r.path);
      await writes.add({ delete: r.path });
    }
    await writes.flush();
    if (rows.length < PARENTS) return;
  }
}
