// What a community's admin does to other people: removing someone from it,
// and deleting it. Both change other people's profiles — the community they
// are in — which the Firestore rules let nobody but this worker write, so
// both run here. Everything else about a community (joining, leaving,
// locking, the description) the app writes itself.

import { WriteQueue, eraseBelow, eraseParents } from './writes.js';

/** Members handled per query while deleting. */
const MEMBERS_PAGE = 100;

/** The ids communities have: Firestore's own, letters and digits. */
export const isCommunityId = (id) => typeof id === 'string' && /^[A-Za-z0-9]{6,40}$/.test(id);

/**
 * Takes [uid] out of community [cid]: the membership and the room's, both
 * counts, and the community on their profile — in one commit, so nobody is
 * ever half out. Whatever is already gone is skipped.
 */
export async function removeMember(store, cid, uid) {
  const community = `communities/${cid}`;
  const room = `rooms/c_${cid}`;
  const member = `${community}/members/${uid}`;
  const roomMember = `${room}/members/${uid}`;
  const user = `users/${uid}`;
  const found = await store.getAll([community, room, member, roomMember, user], ['communityId']);

  const writes = [];
  if (found.get(member)) {
    writes.push({ delete: member });
    if (found.get(community)) writes.push({ increment: community, field: 'memberCount', by: -1 });
  }
  if (found.get(roomMember)) {
    writes.push({ delete: roomMember });
    if (found.get(room)) writes.push({ increment: room, field: 'memberCount', by: -1 });
  }
  if (found.get(user)?.communityId === cid) {
    writes.push({ set: user, field: 'communityId', value: '' });
  }
  if (writes.length) await store.commit(writes);
}

/**
 * Deletes community [cid]. Locked first, so nobody joins while it goes;
 * then everyone in it leaves — each membership with their profile; then its
 * room with every message, its posts with everything on them, and its name,
 * which is free again. The community itself goes last, so while anything is
 * left there is still something saying whose it was.
 *
 * Throws TryAgain when one request is not enough; calling it again carries
 * on from wherever it stopped.
 */
export async function deleteCommunity(store, cid) {
  const community = `communities/${cid}`;
  const info = await store.get(community, ['nameLower', 'locked']);
  if (!info) return;
  if (info.locked !== true) await store.commit([{ set: community, field: 'locked', value: true }]);

  const writes = new WriteQueue(store);
  for (;;) {
    const rows = await store.find({ parent: community, collection: 'members', limit: MEMBERS_PAGE });
    if (!rows.length) break;
    const uids = rows.map((r) => r.path.split('/').pop());
    const profiles = await store.getAll(uids.map((u) => `users/${u}`), ['communityId']);
    for (const uid of uids) {
      const leaving = [{ delete: `${community}/members/${uid}` }];
      // A profile that is gone, or already somewhere else, is left alone.
      if (profiles.get(`users/${uid}`)?.communityId === cid) {
        leaving.push({ set: `users/${uid}`, field: 'communityId', value: '' });
      }
      await writes.add(...leaving);
    }
    await writes.flush();
    if (rows.length < MEMBERS_PAGE) break;
  }

  const room = `rooms/c_${cid}`;
  await eraseBelow(store, writes, room);
  await writes.add({ delete: room });
  await eraseParents(store, writes, { collection: 'posts', field: 'community', value: cid });
  if (info.nameLower) await writes.add({ delete: `communityNames/${info.nameLower}` });
  await writes.add({ delete: community });
  await writes.flush();
}
