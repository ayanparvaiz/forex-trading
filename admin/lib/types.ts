import type { QuerySnapshot, Timestamp } from "firebase/firestore";

/** A time as stored: a Timestamp, or an ISO string from older writes. */
export type When = Timestamp | string | null | undefined;

export type UserDoc = {
  id: string;
  username: string;
  displayName: string;
  avatarId?: number;
  createdAt?: When;
  communityId?: string;
  language?: "bn" | "en";
  gender?: string;
  disciplineScore?: number;
  tradeCount?: number;
  totalR?: number;
  winRate?: number;
  journalStreak?: number;
  badgePoints?: number;
  ranked?: boolean;
  banned?: boolean;
  achievements?: string[];
  weekBoard?: string;
  weekScore?: number;
  weekTrades?: number;
  weekR?: number;
  statsUpdatedAt?: When;
};

export type PostDoc = {
  id: string;
  authorUid: string;
  authorUsername: string;
  community: string;
  kind?: "trade" | "rank" | "question";
  symbol?: string;
  rMultiple?: number;
  reason?: string;
  lesson: string;
  followedRules?: boolean;
  rank?: number;
  disciplineScore?: number;
  claps?: number;
  commentCount?: number;
  reach?: number;
  answerId?: string | null;
  postedAt?: When;
  expiresAt?: When;
};

export type CommentDoc = {
  id: string;
  authorUid: string;
  authorUsername: string;
  authorName?: string;
  authorAvatarId?: number;
  body: string;
  createdAt?: When;
  likedBy?: string[];
};

export type ReportDoc = {
  id: string;
  reporterUid: string;
  kind: "user" | "message" | "post" | "comment";
  targetUid: string;
  targetUsername: string;
  reason: string;
  note?: string;
  quote?: string;
  chatId?: string;
  messageId?: string;
  postId?: string;
  commentId?: string;
  createdAt?: When;
  status: "open" | "resolved" | "dismissed";
  resolvedAt?: When;
  resolvedBy?: string;
};

export type CommunityDoc = {
  id: string;
  name: string;
  description?: string;
  avatarId?: number;
  createdBy: string;
  memberCount?: number;
  locked?: boolean;
  slowSeconds?: number;
  rules?: string[];
  titles?: string[];
  createdAt?: When;
};

export type MessageDoc = {
  id: string;
  senderUid: string;
  senderName?: string;
  senderUsername?: string;
  text: string;
  sentAt?: When;
  unsent?: boolean;
  removed?: boolean;
  attachment?: { type: string; [k: string]: unknown };
  reactions?: Record<string, string>;
};

/** A query's documents, each with its id. */
export function rows<T extends { id: string }>(snap: QuerySnapshot): T[] {
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as T);
}
