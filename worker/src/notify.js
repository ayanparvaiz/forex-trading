// Push notifications for things that have just happened.
//
// The app that did the thing asks — "I sent a message", "I asked her to
// connect" — and this checks that it really happened, by the one asking,
// moments ago, and has not been announced already. Only then does anyone's
// phone buzz. Nobody can make a phone announce something that did not
// happen, or announce the same thing twice.
//
// Who is told, and who is not, follows the app: not someone who has blocked
// the sender, not a conversation they have muted, and not on a phone where
// notifications are turned off — such a phone has no entry to send to.

import { TryAgain } from './firestore.js';
import { pushMessage } from './fcm.js';

/** An event older than this is not news. */
const FRESH_MS = 10 * 60 * 1000;

/**
 * Pushes per request. The free plan allows 50 outgoing requests per
 * incoming one, and the reads before sending need some of them.
 */
export const MAX_PUSHES = 25;

/** Global, or a community's room: `c_` and the community's id. */
const isRoom = (id) => id === 'global' || (typeof id === 'string' && /^c_[A-Za-z0-9]{6,40}$/.test(id));

const TEXT = {
  bn: {
    global: 'গ্লোবাল',
    post: '📊 পোস্ট',
    rank: '🏅 লিডারবোর্ড র‍্যাংক',
    request: 'আপনাকে কানেকশন রিকোয়েস্ট পাঠিয়েছেন',
    accepted: 'আপনার কানেকশন রিকোয়েস্ট অ্যাকসেপ্ট করেছেন',
    newPost: 'নতুন পোস্ট',
    dailyTitle: 'আজকের ১০,০০০ পয়েন্ট এসে গেছে 🌅',
    dailyBody: 'নতুন দিন, নতুন সুযোগ — প্ল্যান মেনে প্র্যাকটিস শুরু করুন।',
  },
  en: {
    global: 'Global',
    post: '📊 Post',
    rank: '🏅 Leaderboard rank',
    request: 'sent you a connection request',
    accepted: 'accepted your connection request',
    newPost: 'New post',
    dailyTitle: "Today's 10,000 points are here 🌅",
    dailyBody: 'A new day to practise — trade your plan.',
  },
};

const textFor = (language) => TEXT[language] ?? TEXT.bn;

/** A message as one line, as the inbox shows it. */
function preview(t, text, attachment) {
  const label = attachment?.type === 'post' ? t.post : attachment?.type === 'rank' ? t.rank : null;
  if (!label) return text;
  return text ? `${label} · ${text}` : label;
}

const isId = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);

/** Whether a stored time is within the last few minutes. */
function fresh(iso, now) {
  const t = Date.parse(iso ?? '');
  return Number.isFinite(t) && now - t < FRESH_MS && t - now < 60_000;
}

function muted(prefs, now) {
  const until = Date.parse(prefs?.mutedUntil ?? '');
  return Number.isFinite(until) && until > now;
}

const skip = (why) => ({ sent: 0, skipped: why });

/**
 * Records that [key] has been announced. False if it already was — the
 * write only succeeds on a key nobody has written.
 */
async function firstTime(store, key, now) {
  try {
    await store.commit([{ create: `pushLog/${key}`, fields: { at: new Date(now) } }]);
    return true;
  } catch (error) {
    if (error instanceof TryAgain) return false;
    throw error;
  }
}

/** The phones of [uids], thirty accounts to a query. */
async function devicesOf(store, uids) {
  const out = [];
  for (let i = 0; i < uids.length; i += 30) {
    const rows = await store.find({
      collection: 'devices',
      group: true,
      field: 'uid',
      op: 'in',
      value: uids.slice(i, i + 30),
      limit: 200,
      fields: ['uid', 'language'],
    });
    for (const r of rows) {
      out.push({ path: r.path, token: r.path.split('/').pop(), language: r.data.language });
    }
  }
  return out;
}

/**
 * Sends one push per phone, built by [build], up to [MAX_PUSHES]. Phones
 * FCM no longer knows are forgotten.
 */
async function deliver(store, push, devices, build) {
  let sent = 0;
  let failed = 0;
  const gone = [];
  for (const device of devices.slice(0, MAX_PUSHES)) {
    try {
      if ((await push(build(device))) === 'gone') gone.push({ delete: device.path });
      else sent++;
    } catch (error) {
      failed++;
      console.warn('push failed:', error.message);
    }
  }
  if (gone.length) {
    await store.commit(gone).catch((e) => console.warn('forgetting phones failed:', e.message));
  }
  return { sent, failed, forgotten: gone.length };
}

async function aMessage(store, push, caller, { chatId, messageId }, now) {
  if (!isId(chatId) || !isId(messageId)) return skip('bad request');
  const chat = await store.get(`chats/${chatId}`, ['uids']);
  if (!chat?.uids?.includes(caller)) return skip('not your conversation');
  const msg = await store.get(`chats/${chatId}/messages/${messageId}`, [
    'senderUid', 'text', 'sentAt', 'unsent', 'attachment',
  ]);
  if (!msg || msg.senderUid !== caller || msg.unsent || !fresh(msg.sentAt, now)) {
    return skip('not news');
  }
  const to = chat.uids.find((u) => u !== caller);
  if (!to || !(await firstTime(store, `msg_${chatId}_${messageId}`, now))) {
    return skip('already told');
  }

  const found = await store.getAll(
    [`users/${to}/blocks/${caller}`, `users/${to}/chatPrefs/${chatId}`, `users/${caller}`],
    ['mutedUntil', 'displayName', 'username'],
  );
  if (found.get(`users/${to}/blocks/${caller}`)) return skip('blocked');
  if (muted(found.get(`users/${to}/chatPrefs/${chatId}`), now)) return skip('muted');
  const sender = found.get(`users/${caller}`) ?? {};

  return deliver(store, push, await devicesOf(store, [to]), (d) =>
    pushMessage({
      token: d.token,
      title: sender.displayName ?? '',
      body: preview(textFor(d.language), msg.text ?? '', msg.attachment),
      data: { type: 'message', chatId, otherUid: caller, otherUsername: sender.username ?? '' },
      group: chatId,
    }));
}

async function aRoomMessage(store, push, caller, { roomId, messageId }, now) {
  if (!isRoom(roomId) || !isId(messageId)) return skip('bad request');
  const docs = await store.getAll(
    [`rooms/${roomId}`, `rooms/${roomId}/messages/${messageId}`],
    ['name', 'senderUid', 'senderName', 'text', 'sentAt', 'unsent', 'attachment'],
  );
  const room = docs.get(`rooms/${roomId}`);
  const msg = docs.get(`rooms/${roomId}/messages/${messageId}`);
  if (!room || !msg || msg.senderUid !== caller || msg.unsent || !fresh(msg.sentAt, now)) {
    return skip('not news');
  }
  if (!(await firstTime(store, `room_${roomId}_${messageId}`, now))) return skip('already told');

  // Members only: joining is what asks for these.
  const members = (await store.find({ parent: `rooms/${roomId}`, collection: 'members', limit: 300 }))
    .map((r) => r.path.split('/').pop())
    .filter((uid) => uid !== caller);
  if (!members.length) return { sent: 0 };
  const found = await store.getAll(
    [
      ...members.map((m) => `users/${m}/blocks/${caller}`),
      ...members.map((m) => `users/${m}/chatPrefs/${roomId}`),
    ],
    ['mutedUntil'],
  );
  const told = members.filter(
    (m) => !found.get(`users/${m}/blocks/${caller}`)
      && !muted(found.get(`users/${m}/chatPrefs/${roomId}`), now),
  );

  return deliver(store, push, await devicesOf(store, told), (d) => {
    const t = textFor(d.language);
    return pushMessage({
      token: d.token,
      // Global in their language; a community's room by its name.
      title: roomId === 'global' ? t.global : room.name ?? '',
      body: `${msg.senderName ?? ''}: ${preview(t, msg.text ?? '', msg.attachment)}`,
      data: { type: 'room', roomId },
      group: roomId,
    });
  });
}

async function aConnection(store, push, caller, { pair }, now, accepted) {
  if (!isId(pair)) return skip('bad request');
  const c = await store.get(`connections/${pair}`, ['fromUid', 'toUid', 'accepted', 'requestedAt']);
  if (!c) return skip('no such connection');
  // A request is news from its sender, moments after it was made; an
  // acceptance, from the person it was sent to, once it is accepted.
  const ok = accepted
    ? c.accepted === true && c.toUid === caller
    : c.accepted === false && c.fromUid === caller && fresh(c.requestedAt, now);
  if (!ok) return skip('not news');
  const key = `${accepted ? 'acc' : 'req'}_${pair}_${Date.parse(c.requestedAt ?? '') || 0}`;
  if (!(await firstTime(store, key, now))) return skip('already told');

  const to = accepted ? c.fromUid : c.toUid;
  const who = (await store.get(`users/${caller}`, ['displayName', 'username'])) ?? {};
  return deliver(store, push, await devicesOf(store, [to]), (d) => {
    const t = textFor(d.language);
    return pushMessage({
      token: d.token,
      title: who.displayName ?? '',
      body: accepted ? t.accepted : t.request,
      // Accepting opened a conversation; a request is answered on a profile.
      data: accepted
        ? { type: 'message', chatId: pair, otherUid: caller, otherUsername: who.username ?? '' }
        : { type: 'profile', username: who.username ?? '' },
      group: `connection_${pair}`,
    });
  });
}

async function aPost(store, push, caller, { postId }, now) {
  if (!isId(postId)) return skip('bad request');
  const post = await store.get(`posts/${postId}`, ['authorUid', 'lesson', 'postedAt', 'community']);
  if (!post || post.authorUid !== caller || !fresh(post.postedAt, now)) return skip('not news');
  if (!(await firstTime(store, `post_${postId}`, now))) return skip('already told');

  // Everyone the author is connected to.
  const connections = await store.find({
    collection: 'connections',
    field: 'uids',
    op: 'array-contains',
    value: caller,
    limit: 300,
    fields: ['uids', 'accepted'],
  });
  let to = connections
    .filter((c) => c.data.accepted === true)
    .map((c) => (c.data.uids ?? []).find((u) => u !== caller))
    .filter(Boolean);

  // A community's post is for its members: only connections who are in it
  // can read it, so only they hear about it.
  const community = post.community ?? 'global';
  if (community !== 'global' && to.length) {
    const members = await store.getAll(to.map((u) => `communities/${community}/members/${u}`), ['role']);
    to = to.filter((u) => members.get(`communities/${community}/members/${u}`));
  }
  if (!to.length) return { sent: 0 };

  const who = (await store.get(`users/${caller}`, ['displayName'])) ?? {};
  const lesson = (post.lesson ?? '').slice(0, 140);
  return deliver(store, push, await devicesOf(store, to), (d) =>
    pushMessage({
      token: d.token,
      title: who.displayName ?? '',
      body: `${textFor(d.language).newPost}: ${lesson}`,
      data: { type: 'post', postId },
      group: `post_${postId}`,
    }));
}

/**
 * Announces [event], something [caller] says they just did. [push] sends
 * one message and says 'sent' or 'gone'. Returns what happened.
 */
export function notify(store, push, caller, event, now = Date.now()) {
  switch (event?.type) {
    case 'message':
      return aMessage(store, push, caller, event, now);
    case 'room':
      return aRoomMessage(store, push, caller, event, now);
    case 'connectionRequest':
      return aConnection(store, push, caller, event, now, false);
    case 'connectionAccepted':
      return aConnection(store, push, caller, event, now, true);
    case 'post':
      return aPost(store, push, caller, event, now);
    default:
      return Promise.resolve(skip('unknown event'));
  }
}

/** The morning reminder that today's points are here, to everyone following it. */
export async function dailyReminder(push) {
  for (const language of Object.keys(TEXT)) {
    const t = TEXT[language];
    await push(pushMessage({
      topic: `daily_${language}`,
      title: t.dailyTitle,
      body: t.dailyBody,
      data: { type: 'daily' },
    }));
  }
}

/** Forgets what was announced more than a few days ago. */
export async function forgetOldAnnouncements(store, now = Date.now()) {
  const old = await store.find({
    collection: 'pushLog',
    field: 'at',
    op: '<',
    value: new Date(now - 3 * 24 * 3600 * 1000),
    limit: 400,
  });
  if (old.length) await store.commit(old.map((r) => ({ delete: r.path })));
  return old.length;
}
