import { auth, WORKER } from "./firebase";

/**
 * Asks the worker to do [action] as the signed-in admin. Long jobs —
 * deleting an account or a community — answer {done: false} until they are
 * finished, so this calls again until they are.
 */
export async function adminCall<T = Record<string, unknown>>(
  action: string,
  body: Record<string, unknown> = {},
): Promise<T> {
  const user = auth.currentUser;
  if (!user) throw new Error("Sign in first.");
  let ask: Record<string, unknown> = { action, ...body };
  for (let round = 0; round < 25; round++) {
    const token = await user.getIdToken();
    const res = await fetch(`${WORKER}/admin`, {
      method: "POST",
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
      body: JSON.stringify(ask),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(describe(data.error, res.status));
    if (data.done === false) {
      // A job in rounds that says where the next one starts.
      if (typeof data.next === "number") ask = { ...ask, from: data.next };
      continue;
    }
    return data as T;
  }
  throw new Error("This is taking a while. Try again in a minute; it picks up where it stopped.");
}

function describe(error: unknown, status: number): string {
  switch (error) {
    case "not an admin":
      return "This account is not an admin.";
    case "not yourself":
      return "You can't do that to your own account.";
    case "not another admin":
      return "That account is an admin. Remove its admin access first.";
    case "no such account":
      return "That account no longer exists.";
    case "no such message":
      return "That message no longer exists.";
    case "no such username":
      return "No account has that username.";
    case "an owner, removed only with tool/make_admin.py":
      return "That admin is an owner. Owners are removed only with tool/make_admin.py.";
    case "that name is taken":
      return "Another community already has that name.";
    case "they are not in the community":
      return "They need to be in the community first.";
    case "lift their ban first":
      return "That account is banned. Lift the ban first.";
    default:
      return typeof error === "string" && error ? error : `The server said no (${status}).`;
  }
}
