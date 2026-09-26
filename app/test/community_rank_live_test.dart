import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/communities_repository.dart';
import 'package:forex_trading/models/community.dart';
import 'package:forex_trading/models/trader.dart';

import 'community_test.dart' show community, trader;

void main() {
  test('waits for the board, then re-ranks as either moves', () async {
    final all = StreamController<List<Community>>();
    final board = StreamController<List<Trader>>();
    final seen = <List<String>>[];
    final sub = rankLive(
      all.stream,
      board.stream,
    ).listen((r) => seen.add([for (final (c, p) in r) '${c.id}:$p']));

    all.add([community('a', 'A', members: 5), community('b', 'B')]);
    await pumpEventQueue();
    expect(seen, isEmpty, reason: 'no order before the board is known');

    board.add([trader('t1', community: 'b')]);
    await pumpEventQueue();
    expect(seen.last, ['b:50', 'a:0']);

    board.add([trader('t1', community: 'a')]);
    await pumpEventQueue();
    expect(seen.last, ['a:50', 'b:0']);

    all.add([community('a', 'A', members: 5), community('c', 'C')]);
    await pumpEventQueue();
    expect(seen.last, ['a:50', 'c:0']);

    await sub.cancel();
    expect(all.hasListener, isFalse);
    expect(board.hasListener, isFalse);
  });

  test('a failing board still lists communities, on zero', () async {
    final all = StreamController<List<Community>>();
    final board = StreamController<List<Trader>>();
    final seen = <List<(Community, int)>>[];
    final sub = rankLive(all.stream, board.stream).listen(seen.add);

    all.add([community('a', 'A'), community('b', 'B', members: 2)]);
    board.addError(Exception('no index'));
    await pumpEventQueue();
    expect([for (final (c, p) in seen.last) '${c.id}:$p'], ['b:0', 'a:0']);
    await sub.cancel();
  });
}
