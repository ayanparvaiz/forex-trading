import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_eraser.dart';

/// A stand-in worker that answers each call from [replies] in turn.
Future<(HttpServer, List<String?>)> fakeWorker(
  List<(int, Map<String, Object?>)> replies,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final seen = <String?>[];
  var i = 0;
  server.listen((request) async {
    seen.add(request.headers.value(HttpHeaders.authorizationHeader));
    final (status, body) = replies[i < replies.length ? i : replies.length - 1];
    i++;
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  });
  return (server, seen);
}

AccountEraser eraserFor(HttpServer server) => AccountEraser(
  endpoint: Uri.parse('http://127.0.0.1:${server.port}/delete-account'),
);

void main() {
  test('keeps calling until the worker says it is done', () async {
    final (server, seen) = await fakeWorker([
      (200, {'done': false}),
      (200, {'done': false}),
      (200, {'done': true}),
    ]);
    addTearDown(() => server.close(force: true));

    await eraserFor(server).erase('token-1');

    expect(seen, ['Bearer token-1', 'Bearer token-1', 'Bearer token-1']);
  });

  test('a refusal stops at once, with the status', () async {
    final (server, seen) = await fakeWorker([
      (403, {'error': 'sign in again'}),
    ]);
    addTearDown(() => server.close(force: true));

    await expectLater(
      eraserFor(server).erase('stale'),
      throwsA(isA<AccountEraseFailed>().having((e) => e.status, 'status', 403)),
    );
    expect(seen, hasLength(1));
  });

  test('a worker that never finishes is given up on', () async {
    final (server, seen) = await fakeWorker([
      (200, {'done': false}),
    ]);
    addTearDown(() => server.close(force: true));

    await expectLater(
      eraserFor(server).erase('t'),
      throwsA(
        isA<AccountEraseFailed>().having((e) => e.status, 'status', null),
      ),
    );
    expect(seen.length, greaterThan(1));
  });

  test('an unreachable worker is a failure, not a hang', () async {
    // Bound and closed at once, so nothing is listening on the port.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);

    await expectLater(
      AccountEraser(
        endpoint: Uri.parse('http://127.0.0.1:$port/delete-account'),
      ).erase('t'),
      throwsA(isA<AccountEraseFailed>()),
    );
  });

  test('points at the same worker as the scores', () {
    expect(deleteAccountEndpoint.path, '/delete-account');
    expect(deleteAccountEndpoint.host, contains('workers.dev'));
  });
}
