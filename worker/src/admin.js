// What the admin panel (admin/) asks of the server. Every change an admin
// makes goes through here: the rules let admins read, never write, so this is
// the one place their power lives — and each request is checked against
// admins/{uid} before anything is done.
//
// POST /admin  { action, ... }  with the admin's Firebase ID token.

import { deleteCommunity, isCommunityId, removeMember } from './community.js';
import { eraseAccount } from './erase.js';
import { pushMessage } from './fcm.js';
import { deliver, devicesOf } from './notify.js';
import { WriteQueue, eraseBelow } from './writes.js';

const isId = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const isUid = (v) => typeof v === 'string' && /^[A-Za-z0-9]{1,128}$/.test(v);
const isRoom = (v) => v === 'global' || (typeof v === 'string' && /^c_[A-Za-z0-9]{6,40}$/.test(v));
// As the app takes them (app/lib/data/auth_repository.dart).
const isUsername = (v) => typeof v === 'string' && /^[a-z0-9_]{3,20}$/.test(v);
const MIN_PASSWORD = 6;

const DAY_MS = 24 * 3600 * 1000;
// How long a ban may last when it is not for good.
const BAN_DAYS = [1, 3, 7, 30];

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
 * sign-ins; [push] sends one message; [journal], when given, is where the
 * activity log is written — its own budget, so a long delete cannot leave
 * nothing to log with. Throws AdminError for a request that cannot be done,
 * TryAgain when a long job needs another call.
 */
export async function adminAction(store, { auth, push, journal = store }, caller, body, now = new Date()) {
  if (!(await isAdmin(store, caller))) throw new AdminError(403, 'not an admin');
  const action = body?.action;
  if (typeof action !== 'string' || !Object.hasOwn(ACTIONS, action)) throw bad('unknown action');
  const run = ACTIONS[action];
  const job = { store, auth, push, caller, body, now };
  if (!RECORDED.has(action)) return run(job);
  // Looked up first: once a post or an account is deleted there is nothing
  // left to say what it was.
  const about = await describe(journal, caller, body);
  const result = await run(job);
  await record(journal, caller, body, about, result, now);
  return result;
}

const ACTIONS = {
  whoami: () => ({ admin: true }),
  ban: ({ store, auth, caller, body, now }) => ban(store, auth, caller, body, now),
  setPassword: ({ store, auth, caller, body }) => setPassword(store, auth, caller, body),
  warn: ({ store, push, caller, body }) => warn(store, push, caller, body),
  resetProfile: ({ store, caller, body }) => resetProfile(store, caller, body),
  addAdmin: ({ store, caller, body, now }) => addAdmin(store, caller, body, now),
  removeAdmin: ({ store, caller, body }) => removeAdmin(store, caller, body),
  deleteUser: ({ store, auth, caller, body }) => deleteUser(store, auth, caller, body),
  deletePost: ({ store, body }) => deletePost(store, body),
  deleteComment: ({ store, body }) => deleteComment(store, body),
  removeMessage: ({ store, body }) => removeMessage(store, body),
  resolveReport: ({ store, caller, body, now }) => resolveReport(store, caller, body, now),
  community: ({ store, body }) => community(store, body),
  broadcast: ({ store, push, caller, body, now }) => broadcast(store, push, caller, body, now),
};

/** Every action that changes something, and so goes in the activity log. */
const RECORDED = new Set(Object.keys(ACTIONS).filter((a) => a !== 'whoami'));

// --- The activity log -------------------------------------------------------

const clip = (v, n = 120) => (typeof v === 'string' ? v.replace(/\s+/g, ' ').trim().slice(0, n) : undefined);

/**
 * Names and words for what [body] is about: the admin, the person, the post,
 * comment, message, community or report. One read.
 */
async function describe(store, caller, body) {
  const paths = { by: `users/${caller}` };
  if (isUid(body.uid)) paths.user = `users/${body.uid}`;
  if (isId(body.postId)) paths.post = `posts/${body.postId}`;
  if (isId(body.postId) && isId(body.commentId)) paths.comment = `posts/${body.postId}/comments/${body.commentId}`;
  if (isRoom(body.roomId) && isId(body.messageId)) paths.message = `rooms/${body.roomId}/messages/${body.messageId}`;
  if (isCommunityId(body.communityId)) paths.community = `communities/${body.communityId}`;
  if (isId(body.reportId)) paths.report = `reports/${body.reportId}`;
  const found = await store.getAll(Object.values(paths), [
    'username', 'name', 'authorUsername', 'senderUsername', 'targetUsername',
    'body', 'text', 'lesson', 'reason', 'quote',
  ]);
  const doc = (k) => (paths[k] ? found.get(paths[k]) : null) ?? null;
  const post = doc('post');
  const comment = doc('comment');
  const message = doc('message');
  const report = doc('report');
  return {
    byUsername: doc('by')?.username,
    // A deleted account has no profile left; the panel says who it was.
    username: doc('user')?.username ?? (body.uid ? clip(body.username, 40) : undefined),
    communityName: doc('community')?.name,
    author: comment?.authorUsername ?? message?.senderUsername ?? post?.authorUsername ?? report?.targetUsername,
    snippet: clip(comment?.body ?? message?.text ?? post?.lesson ?? post?.reason ?? report?.quote),
    reason: report?.reason,
  };
}

/** One line of the activity log. Never fails the action it records. */
async function record(store, caller, body, about, result, now) {
  const fields = { action: body.action, by: caller, at: now };
  for (const k of ['uid', 'postId', 'commentId', 'roomId', 'messageId', 'reportId', 'communityId', 'op', 'status']) {
    if (typeof body[k] === 'string') fields[k] = body[k];
  }
  if (typeof body.banned === 'boolean') fields.banned = body.banned;
  if (typeof body.days === 'number') fields.days = body.days;
  if (body.action === 'broadcast') fields.title = clip(body.bn?.title, 80);
  for (const [k, v] of Object.entries(about)) if (v !== undefined && v !== null) fields[k] = v;
  // The admin's own words: why they banned, what they warned about.
  if (typeof body.reason === 'string' && body.reason.trim()) fields.reason = clip(body.reason, 200);
  if (typeof body.message === 'string') fields.snippet = clip(body.message, 300);
  if (result && typeof result === 'object') {
    for (const k of ['sent', 'phones']) if (typeof result[k] === 'number') fields[k] = result[k];
    for (const k of ['uid', 'username', 'what']) if (typeof result[k] === 'string' && !fields[k]) fields[k] = result[k];
  }
  try {
    await store.commit([{ create: `adminLog/${crypto.randomUUID()}`, fields }]);
  } catch (error) {
    console.warn('activity log failed:', error.message);
  }
}

/** Nobody bans or deletes themselves, or another admin, from here. */
async function guardTarget(store, caller, uid) {
  if (!isUid(uid)) throw bad();
  if (uid === caller) throw bad('not yourself');
  if (await isAdmin(store, uid)) throw bad('not another admin');
}

/**
 * Stops [uid] signing in — or lets them again — and marks the profile. With
 * [days], only for that long: the worker lifts it when the time is up
 * (liftExpiredBans). [reason] is for the activity log, not the profile.
 */
async function ban(store, auth, caller, { uid, banned, days, reason }, now) {
  if (typeof banned !== 'boolean') throw bad();
  if (days !== undefined && !(banned && BAN_DAYS.includes(days))) throw bad();
  if (reason !== undefined && (typeof reason !== 'string' || reason.length > 200)) throw bad();
  await guardTarget(store, caller, uid);
  const profile = await store.get(`users/${uid}`, ['username']);
  if (!profile) throw new AdminError(404, 'no such account');
  await auth.setDisabled(uid, banned);
  const until = banned && days ? new Date(now.getTime() + days * DAY_MS) : null;
  await store.commit([{
    patch: `users/${uid}`,
    fields: until ? { banned, bannedUntil: until } : { banned },
    remove: until ? [] : ['bannedUntil'],
  }]);
  return until ? { banned, until: until.toISOString() } : { banned };
}

/**
 * Lifts the bans whose time is up — a few each run, so a run stays inside
 * the free plan's requests; any left over go on the next.
 */
export async function liftExpiredBans(store, auth, now = new Date(), most = 5) {
  const due = await store.find({
    collection: 'users',
    field: 'bannedUntil',
    op: '<',
    value: now,
    limit: most,
    fields: ['username'],
  });
  for (const { path, data } of due) {
    const uid = path.split('/')[1];
    await auth.setDisabled(uid, false);
    await store.commit([
      { patch: path, fields: { banned: false }, remove: ['bannedUntil'] },
      {
        create: `adminLog/${crypto.randomUUID()}`,
        fields: { action: 'liftBan', by: 'system', at: now, uid, username: data.username ?? '' },
      },
    ]);
  }
  return due.length;
}

/**
 * A new password for [uid], who has forgotten theirs: the app has no other
 * way back in. They are signed out everywhere, too.
 */
async function setPassword(store, auth, caller, { uid, password }) {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD || password.length > 64) {
    throw bad('the password needs 6 to 64 characters');
  }
  await guardTarget(store, caller, uid);
  if (!(await store.get(`users/${uid}`, ['username']))) throw new AdminError(404, 'no such account');
  await auth.setPassword(uid, password);
  return { done: true };
}

const WARNING_TITLE = { bn: 'অ্যাডমিনের সতর্কবার্তা', en: 'A warning from the admins' };

/**
 * A warning, to [uid]'s phones only, in the admin's words. How many phones
 * it reached comes back: none, when they have notifications off.
 */
async function warn(store, push, caller, { uid, message }) {
  if (typeof message !== 'string' || !message.trim() || message.length > 300) throw bad();
  await guardTarget(store, caller, uid);
  if (!(await store.get(`users/${uid}`, ['username']))) throw new AdminError(404, 'no such account');
  const devices = await devicesOf(store, [uid]);
  const { sent } = await deliver(store, push, devices, (d) => pushMessage({
    token: d.token,
    title: WARNING_TITLE[d.language] ?? WARNING_TITLE.bn,
    body: message.trim(),
    data: { type: 'warning' },
  }));
  return { done: true, phones: sent };
}

/**
 * A name or picture nobody should have to see, put back to plain: the name
 * becomes their username, the picture the first one. What is already
 * written under the old name — comments, messages — keeps it.
 */
async function resetProfile(store, caller, { uid, name, avatar }) {
  if (name !== true && avatar !== true) throw bad();
  await guardTarget(store, caller, uid);
  const profile = await store.get(`users/${uid}`, ['username']);
  if (!profile?.username) throw new AdminError(404, 'no such account');
  const fields = {};
  if (name) Object.assign(fields, { displayName: profile.username, nameLower: profile.username.toLowerCase() });
  if (avatar) fields.avatarId = 1;
  await store.commit([{ patch: `users/${uid}`, fields }]);
  return { done: true, what: name && avatar ? 'name and picture' : name ? 'name' : 'picture' };
}

// --- Admins ----------------------------------------------------------------

/** Makes the account named [username] an admin. */
async function addAdmin(store, caller, { username }, now) {
  const name = typeof username === 'string' ? username.trim().toLowerCase().replace(/^@/, '') : '';
  if (!isUsername(name)) throw bad('no such username');
  const claim = await store.get(`usernames/${name}`, ['uid']);
  if (!isUid(claim?.uid)) throw new AdminError(404, 'no such username');
  const profile = await store.get(`users/${claim.uid}`, ['username', 'banned']);
  if (!profile) throw new AdminError(404, 'no such username');
  if (profile.banned) throw bad('lift their ban first');
  if (!(await isAdmin(store, claim.uid))) {
    await store.commit([{
      create: `admins/${claim.uid}`,
      fields: { username: profile.username ?? name, addedAt: now, addedBy: caller },
    }]);
  }
  return { done: true, uid: claim.uid, username: profile.username ?? name };
}

/**
 * Takes [uid]'s admin access away — anyone's but your own, and never an
 * owner's: one set up by hand with tool/make_admin.py is removed only that
 * way, so nobody made an admin in the panel can lock out who made them.
 */
async function removeAdmin(store, caller, { uid }) {
  if (!isUid(uid)) throw bad();
  // So there is always someone left: you cannot be the one to go.
  if (uid === caller) throw bad('not yourself');
  const entry = await store.get(`admins/${uid}`, ['addedBy']);
  if (!entry) return { done: true };
  if (!entry.addedBy) throw bad('an owner, removed only with tool/make_admin.py');
  await store.commit([{ delete: `admins/${uid}` }]);
  return { done: true };
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
 * line in each language reaches all of them. Kept under announcements/, for
 * the panel to show what went out and who sent it.
 */
async function broadcast(store, push, caller, { bn, en }, now) {
  const ok = (m) => m && typeof m.title === 'string' && typeof m.body === 'string'
    && m.title.trim() && m.body.trim() && m.title.length <= 80 && m.body.length <= 300;
  if (!ok(bn) || !ok(en)) throw bad();
  const sent = {
    bn: { title: bn.title.trim(), body: bn.body.trim() },
    en: { title: en.title.trim(), body: en.body.trim() },
  };
  for (const language of ['bn', 'en']) {
    await push(pushMessage({
      topic: `daily_${language}`,
      ...sent[language],
      data: { type: 'announcement' },
    }));
  }
  await store.commit([{
    create: `announcements/${crypto.randomUUID()}`,
    fields: { ...sent, sentBy: caller, sentAt: now },
  }]);
  return { sent: 2 };
}

/** Disabling, re-passwording and deleting sign-ins, with the service account's token. */
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
    // Signed out everywhere with it: whoever had the account loses it.
    setPassword: (uid, password) => call('update', {
      localId: uid,
      password,
      validSince: String(Math.floor(Date.now() / 1000)),
    }),
    remove: (uid) => call('delete', { localId: uid }),
  };
}
