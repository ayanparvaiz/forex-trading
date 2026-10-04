// Asking the admins for a way back in. The app has no password reset — no
// email, nothing that identifies a person — so someone locked out leaves
// their username and a way to reach them, and an admin who is sure it is
// them sets a new password from the panel.
//
// POST /help  { username, contact, note }  — no sign-in: it is for people
// who cannot sign in. The answer is the same whether or not the username
// exists, and there is only ever one open request per account.

export class HelpError extends Error {}

const USERNAME = /^[a-z0-9_]{3,20}$/;

export async function passwordHelp(store, body, now = new Date()) {
  const username = typeof body?.username === 'string' ? body.username.trim().toLowerCase().replace(/^@/, '') : '';
  const contact = typeof body?.contact === 'string' ? body.contact.trim() : '';
  const note = typeof body?.note === 'string' ? body.note.trim() : '';
  if (!USERNAME.test(username) || contact.length < 3 || contact.length > 100 || note.length > 300) {
    throw new HelpError('bad request');
  }
  const claim = await store.get(`usernames/${username}`, ['uid']);
  if (typeof claim?.uid !== 'string') return { ok: true };
  const path = `helpRequests/pw_${claim.uid}`;
  const open = await store.get(path, ['status']);
  if (open?.status === 'open') return { ok: true };
  await store.commit([{
    put: path,
    fields: { kind: 'password', uid: claim.uid, username, contact, note, createdAt: now, status: 'open' },
  }]);
  return { ok: true };
}
