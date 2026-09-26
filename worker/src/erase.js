// Deleting an account: everything the privacy policy says goes, goes.
//
// The list is section 7 of the policy (app/lib/legal/legal_text.dart):
// profile and username, trades and scores, posts, comments and likes,
// connections, notifications, profile-view records, conversations — for
// both people in them — messages in the Global room and in community rooms,
// and community membership. Reports stay, for moderation. A community they
// started is deleted with them, and everyone in it leaves: a community is
// never left without its admin.
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

import { deleteCommunity } from './community.js';
import { PAGE, WriteQueue, eraseBelow, eraseMatching, eraseParents, parentOf } from './writes.js';

// The room everyone can join, made by hand; see firestore.rules. Community
// rooms are found from the account: the one it is in, and any it wrote in.
const GLOBAL = 'global';

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
 * The rooms they wrote in, beyond [known]: a community room they have since
 * left still holds what they said there. Found through their messages, and
 * chats are gone by now, so any message left is in a room.
 */
async function roomsWrittenIn(store, uid, known) {
  const rows = await store.find({
    collection: 'messages',
    group: true,
    field: 'senderUid',
    value: uid,
    limit: PAGE,
    fields: [],
  });
  const ids = new Set();
  for (const r of rows) {
    const [top, id] = r.path.split('/');
    if (top === 'rooms' && !known.has(id)) ids.add(id);
  }
  return [...ids];
}

/**
 * The rooms: the membership and its place in the count, every message they
 * wrote, and the room's preview when it showed one of theirs — which then
 * shows the newest message left, or nothing.
 */
async function eraseFromRooms(store, writes, uid, communityId) {
  const done = new Set();
  let rooms = [GLOBAL, ...(communityId ? [`c_${communityId}`] : [])];
  while (rooms.length) {
    for (const id of rooms) {
      done.add(id);
      await eraseFromRoom(store, writes, uid, id);
    }
    rooms = await roomsWrittenIn(store, uid, done);
  }
}

async function eraseFromRoom(store, writes, uid, id) {
  const previewFields = ['senderUid', 'senderName', 'text', 'unsent'];
  const room = `rooms/${id}`;
  const info = await store.get(room, ['lastMessage']);

  const member = `${room}/members/${uid}`;
  if (info && (await store.get(member))) {
    // Together, so the count can never lose or gain one on a retry.
    await writes.add({ delete: member }, { increment: room, field: 'memberCount', by: -1 });
    await writes.flush();
  }

  await eraseMatching(store, writes, {
    parent: room,
    collection: 'messages',
    field: 'senderUid',
    value: uid,
  });

  if (info?.lastMessage?.senderUid === uid) {
    const newest = await store.newest(room, 'messages', 'sentAt', previewFields);
    const preview = newest && {
      id: newest.path.split('/').pop(),
      senderUid: newest.data.senderUid ?? '',
      senderName: newest.data.senderName ?? '',
      text: newest.data.text ?? '',
      unsent: newest.data.unsent === true,
    };
    await writes.add({ set: room, field: 'lastMessage', value: preview ?? null });
    await writes.flush();
  }
}

/**
 * Out of the community they are in: the membership and its place in the
 * count, together. The community itself stays, for everyone else in it.
 */
async function eraseFromCommunity(store, writes, uid, communityId) {
  if (!communityId) return;
  const community = `communities/${communityId}`;
  const member = `${community}/members/${uid}`;
  const found = await store.getAll([community, member], ['memberCount']);
  if (!found.get(member)) return;
  const writesFor = [{ delete: member }];
  const count = found.get(community)?.memberCount;
  if (typeof count === 'number' && count > 0) {
    writesFor.push({ increment: community, field: 'memberCount', by: -1 });
  }
  await writes.add(...writesFor);
  await writes.flush();
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
  const profile = await store.get(`users/${uid}`, ['username', 'communityId']);
  if (!profile) return;
  const username = profile.username;
  const communityId = /^[A-Za-z0-9]{6,40}$/.test(profile.communityId ?? '') ? profile.communityId : null;
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
  // Theirs goes with them, before the rooms, so its room goes whole.
  if (communityId) {
    const community = await store.get(`communities/${communityId}`, ['createdBy']);
    if (community?.createdBy === uid) await deleteCommunity(store, communityId);
  }
  await eraseFromRooms(store, writes, uid, communityId);
  await eraseFromCommunity(store, writes, uid, communityId);
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
