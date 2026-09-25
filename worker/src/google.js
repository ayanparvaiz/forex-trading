// Talking to Google from a Cloudflare Worker.
//
// The official Admin SDK needs Node and does not run here, so the two things
// it would do for us are done by hand with Web Crypto: checking that a request
// really comes from a signed-in Firebase user, and getting an access token for
// the service account that writes the scores. Both are RS256 JWTs.

const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/datastore';

// Clocks disagree by a few seconds; five minutes is what Google's own
// libraries allow.
const CLOCK_SKEW_S = 300;

const RSA = { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' };

// --- base64url -------------------------------------------------------------

function b64urlToBytes(s) {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/')
    + '==='.slice((s.length + 3) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function bytesToB64url(bytes) {
  let s = '';
  for (const b of new Uint8Array(bytes)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const jsonToB64url = (obj) => bytesToB64url(new TextEncoder().encode(JSON.stringify(obj)));
const b64urlToJson = (s) => JSON.parse(new TextDecoder().decode(b64urlToBytes(s)));

// --- Verifying a Firebase ID token -----------------------------------------

// Google rotates these keys every few hours and says how long to keep them in
// Cache-Control. Kept per isolate, so most requests never fetch them at all.
let jwks = null;
let jwksExpiresAt = 0;

async function signingKeys() {
  if (jwks && Date.now() < jwksExpiresAt) return jwks;

  const res = await fetch(JWKS_URL);
  if (!res.ok) throw new Error(`jwks ${res.status}`);

  const maxAge = /max-age=(\d+)/.exec(res.headers.get('cache-control') ?? '');
  jwks = (await res.json()).keys;
  jwksExpiresAt = Date.now() + (maxAge ? Number(maxAge[1]) * 1000 : 3600_000);
  return jwks;
}

/**
 * Returns the claims inside a Firebase ID token, or throws.
 *
 * Every check here is one the Admin SDK's verifyIdToken makes. Skipping any of
 * them — the audience in particular — would let a token minted for some other
 * Firebase project write scores into this one.
 */
export async function verifyIdTokenClaims(token, projectId, now = Date.now()) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('malformed token');

  const [h, p, sig] = parts;
  const header = b64urlToJson(h);
  const claims = b64urlToJson(p);

  if (header.alg !== 'RS256') throw new Error('wrong algorithm');

  const jwk = (await signingKeys()).find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('unknown signing key');

  const key = await crypto.subtle.importKey('jwk', jwk, RSA, false, ['verify']);
  const valid = await crypto.subtle.verify(
    RSA.name,
    key,
    b64urlToBytes(sig),
    new TextEncoder().encode(`${h}.${p}`),
  );
  if (!valid) throw new Error('bad signature');

  const t = Math.floor(now / 1000);
  if (claims.aud !== projectId) throw new Error('wrong audience');
  if (claims.iss !== `https://securetoken.google.com/${projectId}`) throw new Error('wrong issuer');
  if (!(claims.exp > t - CLOCK_SKEW_S)) throw new Error('expired');
  if (!(claims.iat <= t + CLOCK_SKEW_S)) throw new Error('issued in the future');
  if (typeof claims.sub !== 'string' || claims.sub === '' || claims.sub.length > 128) {
    throw new Error('no subject');
  }

  return claims;
}

/** The uid inside a Firebase ID token, or throws. */
export async function verifyIdToken(token, projectId, now = Date.now()) {
  return (await verifyIdTokenClaims(token, projectId, now)).sub;
}

/**
 * Whether the person behind [claims] typed their password moments ago.
 *
 * An ID token lives for an hour and is refreshed silently for as long as the
 * app stays signed in, so holding one proves only that a phone is signed in —
 * not that its owner is the one holding it. auth_time is when the password was
 * last actually entered, and the app re-enters it right before anything that
 * cannot be undone.
 */
export function signedInRecently(claims, maxAgeS, now = Date.now()) {
  const at = claims.auth_time;
  if (typeof at !== 'number') return false;
  const age = Math.floor(now / 1000) - at;
  return age >= -CLOCK_SKEW_S && age <= maxAgeS;
}

// --- Service account access token ------------------------------------------

let accessToken = null;
let accessTokenExpiresAt = 0;

function pemToDer(pem) {
  // Secrets pasted through a CLI often arrive with literal "\n" instead of
  // newlines. Accept both rather than failing on a copy-paste detail.
  const body = pem
    .replace(/\\n/g, '\n')
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/**
 * An OAuth access token for the service account, scoped to Firestore only.
 *
 * Firestore's own security rules do not apply to it. That is the point — it is
 * the one writer allowed to set the score fields — and also why the key behind
 * it lives only in Worker secrets and never in the repository.
 */
export async function serviceAccountToken(env) {
  // Refreshed five minutes early so a token never expires mid-request.
  if (accessToken && Date.now() < accessTokenExpiresAt - 300_000) return accessToken;

  const iat = Math.floor(Date.now() / 1000);
  const unsigned = `${jsonToB64url({ alg: 'RS256', typ: 'JWT' })}.${jsonToB64url({
    iss: env.FIREBASE_CLIENT_EMAIL,
    scope: SCOPE,
    aud: TOKEN_URL,
    iat,
    exp: iat + 3600,
  })}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(env.FIREBASE_PRIVATE_KEY),
    RSA,
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(RSA.name, key, new TextEncoder().encode(unsigned));

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${bytesToB64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`token ${res.status}: ${await res.text()}`);

  const body = await res.json();
  accessToken = body.access_token;
  accessTokenExpiresAt = Date.now() + body.expires_in * 1000;
  return accessToken;
}
