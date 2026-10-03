import '../i18n/strings.dart';

/// A title and some words, in one language.
typedef Notice = ({String title, String body});

/// What the admins set for every phone (admin panel → App settings; the
/// worker writes config/app): maintenance, the oldest build still allowed,
/// a banner across the app, the post pinned to Global.
class AppConfig {
  const AppConfig({
    this.maintenance,
    this.minBuild = 0,
    this.updateUrl = '',
    this.banner,
    this.pinnedPostId = '',
  });

  /// Nothing set: the app as it always is.
  static const none = AppConfig();

  /// While the app is closed for maintenance, what to say; null when open.
  final Maintenance? maintenance;

  /// Builds older than this have to update first.
  final int minBuild;

  /// Where the new build is, if the admins said.
  final String updateUrl;

  /// A notice across the top of the app; null when there is none.
  final AppBanner? banner;

  /// The post pinned above the rest of Global; '' for none.
  final String pinnedPostId;

  bool needsUpdate(int build) => build < minBuild;

  factory AppConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    String text(Object? v) => v is String ? v.trim() : '';
    Map<String, dynamic> map(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const {};
    Notice notice(Object? v) =>
        (title: text(map(v)['title']), body: text(map(v)['body']));

    final m = map(json['maintenance']);
    final b = map(json['banner']);
    final bn = notice(b['bn']);
    final en = notice(b['en']);
    return AppConfig(
      maintenance: m['on'] == true
          ? Maintenance(bn: text(m['bn']), en: text(m['en']))
          : null,
      minBuild: (json['minBuild'] as num?)?.toInt() ?? 0,
      updateUrl: text(json['updateUrl']),
      banner:
          b['on'] == true &&
              text(b['id']).isNotEmpty &&
              (bn.title.isNotEmpty || en.title.isNotEmpty)
          ? AppBanner(
              id: text(b['id']),
              warning: b['tone'] == 'warn',
              bn: bn,
              en: en,
            )
          : null,
      pinnedPostId: text(json['pinnedPostId']),
    );
  }
}

class Maintenance {
  const Maintenance({this.bn = '', this.en = ''});

  final String bn;
  final String en;

  /// The admins' words in [lang], the other language's if they left it
  /// empty, null if they wrote nothing.
  String? message(AppLanguage lang) {
    final mine = lang == AppLanguage.bn ? bn : en;
    final other = lang == AppLanguage.bn ? en : bn;
    return mine.isNotEmpty ? mine : (other.isNotEmpty ? other : null);
  }
}

class AppBanner {
  const AppBanner({
    required this.id,
    required this.bn,
    required this.en,
    this.warning = false,
  });

  /// New each time it is put up, so closing one never hides the next.
  final String id;

  /// A warning rather than news.
  final bool warning;

  final Notice bn;
  final Notice en;

  Notice inLanguage(AppLanguage lang) {
    final mine = lang == AppLanguage.bn ? bn : en;
    return mine.title.isNotEmpty ? mine : (lang == AppLanguage.bn ? en : bn);
  }
}

/// The words and links nobody may post (admin panel → Blocked words; the
/// worker writes config/moderation). The rules refuse them; this is so the
/// app can say why before trying.
class BlockedWords {
  const BlockedWords(this.words);

  static const none = BlockedWords([]);

  /// In lower case, as the worker keeps them.
  final List<String> words;

  factory BlockedWords.fromJson(Map<String, dynamic>? json) {
    final words = json?['words'];
    return words is List
        ? BlockedWords([
            for (final w in words)
              if (w is String && w.isNotEmpty) w.toLowerCase(),
          ])
        : none;
  }

  /// The first listed word in [text] — in any case, anywhere, as the rules
  /// look — or null when there is none.
  String? firstIn(String text) {
    if (words.isEmpty) return null;
    final lower = text.toLowerCase();
    for (final w in words) {
      if (lower.contains(w)) return w;
    }
    return null;
  }
}
