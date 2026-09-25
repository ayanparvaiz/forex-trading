import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/push.dart';
import 'package:forex_trading/data/push_notifier.dart';

/// Tapping a notification opens what it was about — read from the data the
/// worker writes (worker/src/notify.js).
void main() {
  test('a message opens the conversation', () {
    final route = PushRoute.fromData({
      'type': 'message',
      'chatId': 'ana-me',
      'otherUid': 'u-ana',
      'otherUsername': 'ana',
    });
    expect(route, isA<OpenChatRoute>());
    route as OpenChatRoute;
    expect(route.chatId, 'ana-me');
    expect(route.otherUid, 'u-ana');
    expect(route.otherUsername, 'ana');
  });

  test('the room, a profile, a post', () {
    expect(
      (PushRoute.fromData({'type': 'room', 'roomId': 'global'})
              as OpenRoomRoute)
          .roomId,
      'global',
    );
    expect(
      (PushRoute.fromData({'type': 'profile', 'username': 'rifat'})
              as OpenProfileRoute)
          .username,
      'rifat',
    );
    expect(
      (PushRoute.fromData({'type': 'post', 'postId': 'p9'}) as OpenPostRoute)
          .postId,
      'p9',
    );
  });

  test('the morning reminder, and anything broken, open nothing', () {
    expect(PushRoute.fromData({'type': 'daily'}), isNull);
    expect(PushRoute.fromData({'type': 'message', 'chatId': 'x'}), isNull);
    expect(PushRoute.fromData({'type': 'post', 'postId': ''}), isNull);
    expect(PushRoute.fromData({}), isNull);
  });

  test('the worker it tells is the one that keeps the scores', () {
    expect(notifyEndpoint.path, '/notify');
    expect(notifyEndpoint.host, contains('workers.dev'));
  });
}
