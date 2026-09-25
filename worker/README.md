# Stats worker

Writes each trader's leaderboard row. The app can't write its own score (the
Firestore rules refuse it), so after a trade closes the app calls this worker,
and the worker reads that trader's trades and writes the numbers.

Firebase would host this as a Cloud Function, but deploying one requires a
billing account. This runs on Cloudflare Workers' free plan instead, which
needs no card.

## What one request does

```
POST /recompute
Authorization: Bearer <Firebase ID token>
```

1. Verifies the ID token against Google's public keys, which yields the uid.
   The caller can only ever recompute **their own** row.
2. Reads `users/{uid}/trades` (up to 500, the same window the app loads).
3. Computes the six numbers in `src/stats.js`.
4. Writes them to `users/{uid}` with an update mask, so nothing else on the
   profile is touched.

The service account bypasses Firestore rules. That is the point: it is the
only writer allowed to set the score fields.

## Deleting an account

```
POST /delete-account
Authorization: Bearer <Firebase ID token, from a sign-in in the last 5 minutes>
```

Erases the caller's account from Firestore: everything section 7 of the
privacy policy lists (`app/lib/legal/legal_text.dart`). Most of it is not the
account's own to delete under the rules, since a conversation belongs to two
people and a like sits on someone else's post, so it runs here. The code and
its order are in `src/erase.js`.

- The token must come from a password typed in the last 5 minutes
  (`auth_time`). The app signs in again on the delete screen right before
  calling.
- One request makes at most 40 Firestore calls, because the free plan allows
  50 outgoing requests. `{"done": false}` means "call again"; each call starts
  from the top and skips what is already gone. The app repeats until
  `{"done": true}`, then deletes the Firebase Auth sign-in itself.
- In the Global room: the membership goes (and the member count drops by
  one), every message they wrote goes, and if the room's preview was one of
  theirs it moves to the newest message left.
- The username is **retired**, not freed. The claim stays, pointing at nobody,
  so nobody else can register the name.
- Reports stay, and so do views on other people's posts (reach), which carry
  only a uid that no longer belongs to anyone.
- It needs three collection-group indexes, in `firestore.indexes.json` under
  `fieldOverrides`.

## The formula exists twice

`src/stats.js` mirrors `app/lib/core/leaderboard_stats.dart`. Both are tested
against `tool/stats_fixture.json`, so they can't drift apart without a test
failing.

If you change the formula:

```sh
cd app && dart run tool/update_stats_fixture.dart   # Dart is the reference
cd ../worker && npm test                            # fails until stats.js matches
```

## Deploying

```sh
cd worker
npx wrangler login
npx wrangler secret put FIREBASE_CLIENT_EMAIL
npx wrangler secret put FIREBASE_PRIVATE_KEY
npx wrangler deploy
```

The two secrets belong to a service account that has
`roles/datastore.user` and nothing else. Never commit the key.

After the first deploy, put the URL wrangler prints into `statsEndpoint` in
`app/lib/data/score_sync.dart`.

## Free-tier budget

Cloudflare's free plan allows 100,000 requests a day. That isn't the limit
that matters.

Firestore's free tier allows **50,000 reads a day for the whole project**, and
one recompute reads every trade the account has. To stop one account from
spending everyone's quota, a recompute is refused if the same account had one
in the last 15 seconds. There are two checks: a Cloudflare cache entry, which
is free and catches most repeats, and a timestamp on the user document, which
costs one read and catches calls that land on a different Cloudflare location.

The honest limit: a signed-in account calling in a loop, every 15 seconds,
with 500 trades, would spend about 2.9 million reads a day. That is far past
the free tier. Firestore on the free plan does not bill for that. It stops
serving until the next day. If that ever becomes a real risk, the fix is to
keep running totals on the user document and update them per trade, instead
of re-reading the whole journal.

## What this does not fix

Prices come from `MockMarket`, which runs **on the phone**. Neither this worker
nor any server can check that a trade's exit price was really the market
price at that moment. The worker trusts the trades and computes from them
faithfully. Closing that gap means making the price series reproducible on the
server. `MockMarket` is already deterministic from its seed, so this is
possible, but it is separate work.
