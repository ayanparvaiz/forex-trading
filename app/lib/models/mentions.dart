/// Someone named with @ in a message: 3–20 letters, digits or underscores,
/// not inside a word — the same rule the worker uses to decide who is told
/// (worker/src/notify.js, mentionsIn). An email address names nobody.
final mentionPattern = RegExp(
  r'(?<![A-Za-z0-9_@])@([A-Za-z0-9_]{3,20})(?![A-Za-z0-9_])',
);

final _nameChar = RegExp(r'[A-Za-z0-9_]');

/// The @name being typed at [cursor] in [text]: where its @ is, and what has
/// been typed after it, lower case. Null when the cursor is not in one.
(int, String)? mentionAt(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  var i = cursor;
  while (i > 0 && _nameChar.hasMatch(text[i - 1])) {
    i--;
  }
  if (i == 0 || text[i - 1] != '@') return null;
  final at = i - 1;
  // Not inside a word: "me@ana" is an address, not a name.
  if (at > 0 && (_nameChar.hasMatch(text[at - 1]) || text[at - 1] == '@')) {
    return null;
  }
  final typed = text.substring(i, cursor);
  if (typed.length > 20) return null;
  return (at, typed.toLowerCase());
}

/// [text] with the @name typed from [at] to [cursor] replaced by the whole
/// of [username] and a space — and where the cursor goes after it.
(String, int) completeMention(
  String text,
  int at,
  int cursor,
  String username,
) {
  final inserted = '@$username ';
  return (text.replaceRange(at, cursor, inserted), at + inserted.length);
}
