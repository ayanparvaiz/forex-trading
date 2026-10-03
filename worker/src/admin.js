// What the admin panel (admin/) asks of the server. Every change an admin
// makes goes through here: the rules let admins read, never write, so this is
// the one place their power lives — and each request is checked against
// admins/{uid} before anything is done.
//
// POST /admin  { action, ... }  with the admin's Firebase ID token.

import { deleteCommunity, isCommunityId, removeMember } from './community.js';
import { eraseAccount } from './erase.js';
import { pushMessage } from './fcm.js';
import { WriteQueue, eraseBelow } from './writes.js';

const isId = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const isUid = (v) => typeof v === 'string' && /^[A-Za-z0-9]{1,128}$/.test(v);
const isRoom = (v) => v === 'global' || (typeof v === 'string' && /^c_[A-Za-z0-9]{6,40}$/.test(v));

export class AdminError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const bad = (why = 'bad request') => new AdminError(400, why);

export async function isAdmin(store, uid) {
  return isUid(uid) && (await store.get(`admins/${uid}`, ['addedAt'])) != null;
}

/**
 * Does [body.action] for admin [caller]. [auth] disables and deletes
 * sign-ins; [push] sends one message. Throws AdminError for a request that
 * cannot be done, TryAgain when a long job needs another call.
 */
export async function adminAction(store, { auth, push }, caller, body, now = new Date()) {
  if (!(await isAdmin(store, caller))) throw new AdminError(403, 'not an admin');
  const action = body?.action;
  switch (action) {
    case 'whoami':
      return { admin: true };
    case 'ban':
      return ban(store, auth, caller, body);
    case 'deleteUser':
      return deleteUser(store, auth, caller, body);
    case 'deletePost':
      return deletePost(store, body);
    case 'deleteComment':
      return deleteComment(store, body);
    case 'removeMessage':
      return removeMessage(store, body);
    case 'resolveReport':
      return resolveReport(store, caller, body, now);
    case 'community':
      return community(store, body);
    case 'broadcast':
      return broadcast(push, body);
    default:
      throw bad('unknown action');
  }
}

/** Nobody bans or deletes themselves, or another admin, from here. */
async function guardTarget(store, caller, uid) {
  if (!isUid(uid)) throw bad();
  if (uid === caller) throw bad('not yourself');
  if (await isAdmin(store, uid)) throw bad('not another admin');
}

/** Stops [uid] signing in — or lets them again — and marks the profile. */
async function ban(store, auth, caller, { uid, banned }) {
  if (typeof banned !== 'boolean') throw bad();
  await guardTarget(store, caller, uid);
  const profile = await store.get(`users/${uid}`, ['username']);
  if (!profile) throw new AdminError(404, 'no such account');
  await auth.setDisabled(uid, banned);
  await store.commit([{ patch: `users/${uid}`, fields: { banned } }]);
  return { banned };
}

/**
 * Erases [uid]'s account as the app's own delete does, then the sign-in.
 * Long accounts take more than one call: {done: false} means call again.
 */
async function deleteUser(store, auth, caller, { uid }) {
  await guardTarget(store, caller, uid);
  await eraseAccount(store, uid);
  await auth.remove(uid);
  return { done: true };
}

/** A post, with its likes, comments and views. */
async function deletePost(store, { postId }) {
  if (!isId(postId)) throw bad();
  const writes = new WriteQueue(store);
  await eraseBelow(store, writes, `posts/${postId}`);
  await writes.add({ delete: `posts/${postId}` });
  await writes.flush();
  return { done: true };
}

/** One comment, and the post's count with it. */
async function deleteComment(store, { postId, commentId }) {
  if (!isId(postId) || !isId(commentId)) throw bad();
  const path = `posts/${postId}/comments/${commentId}`;
  const found = await store.getAll([path, `posts/${postId}`], ['commentCount']);
  if (!found.get(path)) return { done: true };
  const writes = [{ delete: path }];
  const count = found.get(`posts/${postId}`)?.commentCount;
  if (typeof count === 'number' && count > 0) {
    writes.push({ increment: `posts/${postId}`, field: 'commentCount', by: -1 });
  }
  await store.commit(writes);
  return { done: true };
}

/**
 * Takes a room message down, marked as removed — as a community's admin
 * does — and the room's preview with it when it was the newest.
 */
async function removeMessage(store, { roomId, messageId }) {
  if (!isRoom(roomId) || !isId(messageId)) throw bad();
  const path = `rooms/${roomId}/messages/${messageId}`;
  const found = await store.getAll([path, `rooms/${roomId}`], ['senderUid', 'senderName', 'lastMessage']);
  const message = found.get(path);
  if (!message) throw new AdminError(404, 'no such message');
  const writes = [{
    patch: path,
    fields: { text: '', unsent: true, removed: true },
    remove: ['attachment'],
  }];
  const last = found.get(`rooms/${roomId}`)?.lastMessage;
  if (last?.id === messageId) {
    writes.push({
      patch: `rooms/${roomId}`,
      fields: {
        lastMessage: {
          id: messageId,
          senderUid: message.senderUid ?? '',
          senderName: message.senderName ?? '',
          text: '',
          unsent: true,
        },
      },
    });
  }
  await store.commit(writes);
  return { done: true };
}

/** A report dealt with: acted on, or nothing to do. */
async function resolveReport(store, caller, { reportId, status }, now) {
  if (!isId(reportId) || !['resolved', 'dismissed', 'open'].includes(status)) throw bad();
  if (!(await store.get(`reports/${reportId}`, ['status']))) throw new AdminError(404, 'no such report');
  await store.commit([{
    patch: `reports/${reportId}`,
    fields: status === 'open'
      ? { status }
      : { status, resolvedBy: caller, resolvedAt: now },
    remove: status === 'open' ? ['resolvedBy', 'resolvedAt'] : [],
  }]);
  return { status };
}

/** Lock, unlock, delete a community, or remove someone from it. */
async function community(store, { communityId, op, uid }) {
  if (!isCommunityId(communityId)) throw bad();
  const c = await store.get(`communities/${communityId}`, ['createdBy']);
  if (!c) return { done: true };
  switch (op) {
    case 'lock':
    case 'unlock':
      await store.commit([{ patch: `communities/${communityId}`, fields: { locked: op === 'lock' } }]);
      return { locked: op === 'lock' };
    case 'delete':
      await deleteCommunity(store, communityId);
      return { done: true };
    case 'remove':
      if (!isUid(uid)) throw bad();
      // Its admin goes only with the community.
      if (uid === c.createdBy) throw bad('the community admin is not removed; delete the community');
      await removeMember(store, communityId, uid);
      return { done: true };
    default:
      throw bad();
  }
}

/**
 * A notification to everyone who has them on: every phone is subscribed to
 * its language's topic (worker/src/notify.js, the morning reminder), so a
 * line in each language reaches all of them.
 */
async function broadcast(push, { bn, en }) {
  const ok = (m) => m && typeof m.title === 'string' && typeof m.body === 'string'
    && m.title.trim() && m.body.trim() && m.title.length <= 80 && m.body.length <= 300;
  if (!ok(bn) || !ok(en)) throw bad();
  for (const [language, m] of [['bn', bn], ['en', en]]) {
    await push(pushMessage({
      topic: `daily_${language}`,
      title: m.title.trim(),
      body: m.body.trim(),
      data: { type: 'announcement' },
    }));
  }
  return { sent: 2 };
}

/** Disabling and deleting sign-ins, with the service account's token. */
export function identityToolkit(projectId, token) {
  const base = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts`;
  const call = async (verb, body) => {
    const res = await fetch(`${base}:${verb}`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (res.ok) return;
    const text = await res.text();
    // Already gone is what deleting wanted.
    if (verb === 'delete' && text.includes('USER_NOT_FOUND')) return;
    throw new Error(`identity toolkit ${verb} ${res.status}: ${text.slice(0, 200)}`);
  };
  return {
    setDisabled: (uid, disabled) => call('update', {
      localId: uid,
      disableUser: disabled,
      // Signed out everywhere, too: their refresh tokens stop working.
      ...(disabled ? { validSince: String(Math.floor(Date.now() / 1000)) } : {}),
    }),
    remove: (uid) => call('delete', { localId: uid }),
  };
}
