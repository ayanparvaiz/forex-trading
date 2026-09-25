// Deleting an account: everything the privacy policy says goes, goes.
//
// The list is section 7 of the policy (app/lib/legal/legal_text.dart):
// profile and username, trades and scores, posts, comments and likes,
// connections, notifications, profile-view records, and conversations — for
// both people in them. Reports stay, for moderation.
//
// Much of it is not the account's own to delete under the Firestore rules —
// a conversation belongs to two people, a like sits on someone else's post —
// which is why this runs here, with the service account, rather than in the
// app.
//
// Written to be run more than once. A request may stop part-way (TryAgain,
// see firestore.js) and the next one starts from the top: everything already
// deleted is simply not found again. The profile goes last, so while any of
// the rest is left, the profile is still there to say whose it was.

const PAGE = 300;

// Posts and chats are fetched a few at a time: each one costs a further
// query for what is under it.
const PARENTS = 25;

/** Firestore takes at most 500 writes in one commit. */
class WriteQueue {
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

const parentOf = (path) => path.split('/').slice(0, -2).join('/');

/**
 * Deletes every document matching [query], a page at a time.
 *
 * Each page is committed before the next is asked for — otherwise the next
 * query would return the same documents again.
 */
async function eraseMatching(store, writes, query, keep = () => true) {
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
async function eraseBelow(store, writes, path) {
  for (;;) {
    const paths = await store.descendants(path, PAGE);
    for (const p of paths) await writes.add({ delete: p });
    await writes.flush();
    if (paths.length < PAGE) return;
  }
}

/** Documents with things under them: the things first, then the document. */
async function eraseParents(store, writes, query) {
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

/**
 * Comments or likes left on other people's posts, and the counts on those
 * posts that include them.
 *
 * Each removal and its post's count land in one commit, so a count never
 * disagrees with what is there. A count that has already drifted below the
 * truth is clamped at zero rather than taken negative; a post that no longer
 * exists is left not existing — an increment on a missing document would
 * create one.
 */
async function eraseOnOthersPosts(store, writes, uid, { collection, field, counter }) {
  for (;;) {
    const rows = await store.find({ collection, group: true, field, value: uid, limit: PAGE });

    const byPost = new Map();
    for (const r of rows) {
      const post = parentOf(r.path);
      byPost.set(post, [...(byPost.get(post) ?? []), r.path]);
    }
    const counts = await store.getAll([...byPost.keys()], [counter]);

    for (const [post, paths] of byPost) {
      const deletes = paths.map((p) => ({ delete: p }));
      const current = counts.get(post);
      if (current == null) {
        await writes.add(...deletes);
        continue;
      }
      const have = typeof current[counter] === 'number' ? current[counter] : 0;
      const adjust = have >= paths.length
        ? { increment: post, field: counter, by: -paths.length }
        : { set: post, field: counter, value: 0 };
      await writes.add(...deletes, adjust);
    }
    await writes.flush();
    if (rows.length < PAGE) return;
  }
}

/**
 * Erases the account [uid] from Firestore. Throws TryAgain when it has to
 * stop early; calling it again continues.
 *
 * Returns quietly when there is no profile: either a previous call finished,
 * or there was never anything here. The sign-in itself is deleted by the
 * app, which is the one holding it.
 */
export async function eraseAccount(store, uid) {
  const profile = await store.get(`users/${uid}`, ['username']);
  if (!profile) return;
  const username = profile.username;
  const writes = new WriteQueue(store);

  // Their posts, with every comment, like and view on them.
  await eraseParents(store, writes, { collection: 'posts', field: 'authorUid', value: uid });

  // What they left on everyone else's.
  await eraseOnOthersPosts(store, writes, uid, {
    collection: 'comments',
    field: 'authorUid',
    counter: 'commentCount',
  });
  await eraseOnOthersPosts(store, writes, uid, { collection: 'claps', field: 'uid', counter: 'claps' });

  // Conversations go for both people, as the policy says. A conversation with
  // one side gone cannot be answered, and its id would be waiting for
  // whoever might one day hold the same name.
  await eraseParents(store, writes, {
    collection: 'chats',
    field: 'uids',
    op: 'array-contains',
    value: uid,
  });
  await eraseMatching(store, writes, {
    collection: 'connections',
    field: 'uids',
    op: 'array-contains',
    value: uid,
  });

  for (const field of ['recipientUid', 'actorUid']) {
    await eraseMatching(store, writes, { collection: 'notifications', field, value: uid });
  }
  for (const field of ['viewerUid', 'profileUid']) {
    await eraseMatching(store, writes, { collection: 'profileViews', field, value: uid });
  }

  // Other people's blocks of this account. Keyed by the blocked uid, and the
  // username is only there for display, so the id is what decides.
  await eraseMatching(
    store,
    writes,
    { collection: 'blocks', group: true, field: 'username', value: username },
    (r) => r.path.endsWith(`/blocks/${uid}`),
  );

  // Their trades and their own block list.
  await eraseBelow(store, writes, `users/${uid}`);

  // Last, together. The username is retired rather than freed: the claim
  // stays, pointing at no one, so nobody can take the name and be mistaken
  // for the person who had it.
  const claim = username ? await store.get(`usernames/${username}`, ['uid']) : null;
  if (claim?.uid === uid) {
    await writes.add({ replace: `usernames/${username}`, serverTime: 'retiredAt' });
  }
  await writes.add({ delete: `presence/${uid}` }, { delete: `users/${uid}` });
  await writes.flush();
}
