import { collection, getDocs, limit, query } from "firebase/firestore";
import { db } from "./firebase";
import { rows, type CommunityDoc, type UserDoc } from "./types";

/** Every account, at the scale this app is at: one read each. */
export async function allUsers(): Promise<UserDoc[]> {
  return rows<UserDoc>(await getDocs(query(collection(db, "users"), limit(2000))));
}

export async function allCommunities(): Promise<CommunityDoc[]> {
  return rows<CommunityDoc>(await getDocs(query(collection(db, "communities"), limit(500))));
}

/** Communities by id, for showing a name where only the id is stored. */
export async function communityNames(): Promise<Map<string, CommunityDoc>> {
  return new Map((await allCommunities()).map((c) => [c.id, c]));
}
