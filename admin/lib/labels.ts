/** The app's achievements (app/lib/models/achievement.dart), by id. */
export const ACHIEVEMENTS: Record<string, string> = {
  first_trade: "First trade",
  ranked: "Ranked",
  fifty_trades: "50 trades",
  hundred_trades: "100 trades",
  clean_ten: "10 clean trades",
  big_winner: "Big winner",
  streak_7: "7-day journal streak",
  streak_30: "30-day journal streak",
  iron_discipline: "Iron discipline",
  scholar: "Scholar",
};

export const REPORT_REASONS: Record<string, string> = {
  spam: "Spam",
  harassment: "Harassment",
  hate: "Hate",
  sexual: "Sexual content",
  violence: "Violence",
  scam: "Scam",
  impersonation: "Impersonation",
  other: "Other",
};

export const KINDS: Record<string, string> = {
  user: "Account",
  message: "Message",
  post: "Post",
  comment: "Comment",
};
