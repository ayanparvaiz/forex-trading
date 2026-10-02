import 'instrument.dart';

enum MoodSide { up, down }

/// Which way traders think a pair is going today: who said up, who down.
/// Opinions, counted — never advice.
class MarketMood {
  const MarketMood({this.bulls = const {}, this.bears = const {}});

  static const none = MarketMood();

  final Set<String> bulls;
  final Set<String> bears;

  int get votes => bulls.length + bears.length;

  /// The share who said up, 0 to 1; null before anyone has said anything.
  double? get upShare => votes == 0 ? null : bulls.length / votes;

  MoodSide? sideOf(String uid) => bulls.contains(uid)
      ? MoodSide.up
      : bears.contains(uid)
      ? MoodSide.down
      : null;

  /// The same, with [uid] on [side] — or on neither.
  MarketMood withVote(String uid, MoodSide? side) => MarketMood(
    bulls: {...bulls.where((u) => u != uid), if (side == MoodSide.up) uid},
    bears: {...bears.where((u) => u != uid), if (side == MoodSide.down) uid},
  );
}

/// The day votes are counted under: Dhaka's date, as the rules work it out
/// (firestore.rules, dhakaDay) — `20261002`.
String moodDay(DateTime now) {
  final d = now.toUtc().add(const Duration(hours: 6));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${two(d.month)}${two(d.day)}';
}

/// A pair as the rules name it: `EURUSD`.
String moodPair(Instrument instrument) => instrument.symbol.replaceAll('/', '');

/// Everyone's mood, or a community's — its id.
const moodEveryone = 'global';
