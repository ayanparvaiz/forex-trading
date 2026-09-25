// Push notifications, over FCM's HTTP v1 API.
//
// One request per phone: the v1 API has no multicast. The daily reminder
// goes to a topic instead, which is one request for everyone.

/** A push for one phone ([token]) or everyone following a [topic]. */
export function pushMessage({ token, topic, title, body, data = {}, group }) {
  return {
    ...(token ? { token } : { topic }),
    notification: { title, body },
    // FCM data values must be strings.
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    android: {
      priority: 'high',
      // One notification per conversation, replaced as new messages come.
      notification: { ...(group ? { tag: group } : {}), sound: 'default' },
    },
    apns: {
      payload: { aps: { sound: 'default', ...(group ? { 'thread-id': group } : {}) } },
    },
  };
}

/**
 * Sends [message]. 'sent', or 'gone' when the phone's token no longer
 * exists — uninstalled, or signed out — so its entry can be forgotten.
 */
export async function sendPush(projectId, accessToken, message) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ message }),
  });
  if (res.ok) return 'sent';
  const text = await res.text();
  if (res.status === 404 || text.includes('UNREGISTERED') || text.includes('registration token')) {
    return 'gone';
  }
  throw new Error(`fcm ${res.status}: ${text.slice(0, 300)}`);
}
