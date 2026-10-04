// What the worker does for the admins on its own, every quarter hour
// (index.js, ADMIN_CRON): tells them about new reports, hides a post that
// enough people reported until someone looks, and sends announcements
// scheduled for now. Bans whose time is up are lifted in the same run
// (admin.js, liftExpiredBans).

import { TryAgain } from './firestore.js';
import { pushMessage } from './fcm.js';
import { deliver, devicesOf } from './notify.js';

const ALERT_TEXT = {
  bn: { title: 'নতুন রিপোর্ট', body: (n) => `অ্যাডমিন প্যানেলে ${n}টা নতুন রিপোর্ট অপেক্ষা করছে।` },
  en: { title: 'New reports', body: (n) => `${n} new report${n === 1 ? ' is' : 's are'} waiting in the admin panel.` },
};

/**
 * New reports since the last look, to the phones of every admin who wants
 * to hear (admins/{uid}.alerts is not false). The first run only marks
 * where to start from, so nobody is told about old ones.
 */
export async function reportAlerts(store, push, now = new Date()) {
  const state = await store.get('config/alerts', ['lastReportAt']);
  const since = state?.lastReportAt instanceof Date ? state.lastReportAt : null;
  if (!since) {
    await store.commit([{ upsert: 'config/alerts', fields: { lastReportAt: now } }]);
    return { sent: 0 };
  }
  const fresh = await store.find({
    collection: 'reports',
    field: 'createdAt',
    op: '>=',
    value: new Date(since.getTime() + 1),
    limit: 100,
    fields: ['createdAt', 'status'],
  });
  if (!fresh.length) return { sent: 0 };
  const newest = new Date(Math.max(...fresh.map((r) => (r.data.createdAt instanceof Date ? r.data.createdAt.getTime() : 0))));
  await store.commit([{ upsert: 'config/alerts', fields: { lastReportAt: newest } }]);
  const open = fresh.filter((r) => r.data.status === 'open').length;
  if (!open) return { sent: 0 };

  const admins = (await store.find({ collection: 'admins', limit: 50, fields: ['alerts'] }))
    .filter((a) => a.data.alerts !== false)
    .map((a) => a.path.split('/')[1]);
  if (!admins.length) return { sent: 0 };
  const devices = await devicesOf(store, admins);
  // A handful of phones: this shares its run with other work.
  const { sent } = await deliver(store, push, devices, (d) => {
    const t = ALERT_TEXT[d.language] ?? ALERT_TEXT.bn;
    return pushMessage({ token: d.token, title: t.title, body: t.body(open), data: { type: 'adminReports' } });
  }, 5);
  return { sent, reports: open };
}

/** How many people reporting one post hides it, unless the admins set it. */
export const AUTO_HIDE_AT = 3;

/**
 * A post that enough different people reported, taken off the feeds until
 * an admin looks: its expiry moved to now (the feeds show only posts not yet
 * expired), the real one kept to put back. A few each run.
 */
export async function autoHideReported(store, now = new Date(), most = 2) {
  const settings = await store.get('config/moderation', ['autoHideAt']);
  const at = Number.isInteger(settings?.autoHideAt) ? settings.autoHideAt : AUTO_HIDE_AT;
  if (at <= 0) return 0;
  const open = await store.find({
    collection: 'reports',
    field: 'status',
    value: 'open',
    limit: 300,
    fields: ['kind', 'postId', 'reporterUid'],
  });
  const reporters = new Map();
  for (const { data } of open) {
    if (data.kind !== 'post' || typeof data.postId !== 'string' || !data.postId) continue;
    reporters.set(data.postId, (reporters.get(data.postId) ?? new Set()).add(data.reporterUid));
  }
  const due = [...reporters].filter(([, who]) => who.size >= at).map(([id]) => id);
  let hidden = 0;
  for (const postId of due) {
    if (hidden >= most) break;
    const path = `posts/${postId}`;
    const post = await store.get(path, ['expiresAt', 'hiddenByReports', 'authorUsername', 'lesson']);
    if (!post || post.hiddenByReports === true) continue;
    await store.commit([
      {
        patch: path,
        fields: {
          hiddenByReports: true,
          hiddenExpiresAt: post.expiresAt instanceof Date ? post.expiresAt : now,
          expiresAt: now,
        },
      },
      {
        create: `adminLog/${crypto.randomUUID()}`,
        fields: {
          action: 'autoHide',
          by: 'system',
          at: now,
          postId,
          author: post.authorUsername ?? '',
          snippet: String(post.lesson ?? '').replace(/\s+/g, ' ').trim().slice(0, 120),
          reports: reporters.get(postId).size,
        },
      },
    ]);
    hidden++;
  }
  return hidden;
}

/**
 * Announcements scheduled for now or before, sent — one each run, and a big
 * community's in rounds, its place kept on the schedule until it is done.
 * [send] is the panel's own announcing (admin.js, broadcast).
 */
export async function sendScheduled(store, send, now = new Date()) {
  const due = await store.find({
    collection: 'scheduled',
    field: 'at',
    op: '<',
    value: now,
    limit: 1,
    fields: ['bn', 'en', 'communityId', 'by', 'from'],
  });
  if (!due.length) return 0;
  const { path, data } = due[0];
  let result;
  try {
    result = await send(data.by, {
      action: 'broadcast',
      bn: data.bn,
      en: data.en,
      ...(data.communityId ? { communityId: data.communityId } : {}),
      from: Number.isInteger(data.from) ? data.from : 0,
      // Ten phones a round: this shares its run with other work.
      round: 10,
    });
  } catch (error) {
    // Out of requests this run: the next one carries on.
    if (error instanceof TryAgain) return 0;
    // One that can never go — its community deleted, its admin gone — is
    // dropped, not tried every quarter hour for ever.
    console.warn('scheduled announcement failed:', error.message);
    await store.commit([{ delete: path }]);
    return 0;
  }
  await store.commit([
    result?.done === false ? { patch: path, fields: { from: result.next } } : { delete: path },
  ]);
  return 1;
}
