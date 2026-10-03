import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/build_info.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/app_config.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/app_banner.dart';
import 'package:forex_trading/widgets/app_config_host.dart';
import 'package:forex_trading/widgets/app_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('what the admins set, read', () {
    test('nothing set is the app as it is', () {
      for (final json in [null, <String, dynamic>{}]) {
        final c = AppConfig.fromJson(json);
        expect(c.maintenance, isNull);
        expect(c.banner, isNull);
        expect(c.needsUpdate(1), isFalse);
        expect(c.pinnedPostId, '');
      }
    });

    test('maintenance, in the reader language or the other one', () {
      final c = AppConfig.fromJson({
        'maintenance': {'on': true, 'bn': '', 'en': 'Back at 10'},
      });
      expect(c.maintenance!.message(AppLanguage.en), 'Back at 10');
      expect(c.maintenance!.message(AppLanguage.bn), 'Back at 10');
      expect(
        AppConfig.fromJson({
          'maintenance': {'on': false, 'en': 'x'},
        }).maintenance,
        isNull,
      );
      expect(
        AppConfig.fromJson({
          'maintenance': {'on': true},
        }).maintenance!.message(AppLanguage.bn),
        isNull,
        reason: 'no words: the app says its own',
      );
    });

    test('builds older than the oldest allowed must update', () {
      final c = AppConfig.fromJson({
        'minBuild': 3,
        'updateUrl': ' https://x.y ',
      });
      expect(
        [c.needsUpdate(2), c.needsUpdate(3), c.needsUpdate(4)],
        [true, false, false],
      );
      expect(c.updateUrl, 'https://x.y');
    });

    test('a banner needs to be on, to have an id and a title', () {
      Map<String, dynamic> banner(Map<String, dynamic> over) => {
        'banner': {
          'on': true,
          'id': 'b1',
          'tone': 'warn',
          'bn': {'title': 'হালনাগাদ', 'body': ''},
          'en': {'title': 'Update', 'body': 'Read this'},
          ...over,
        },
      };
      final b = AppConfig.fromJson(banner({})).banner!;
      expect([b.id, b.warning], ['b1', true]);
      expect(b.inLanguage(AppLanguage.en), (
        title: 'Update',
        body: 'Read this',
      ));
      expect(b.inLanguage(AppLanguage.bn).title, 'হালনাগাদ');
      expect(AppConfig.fromJson(banner({'on': false})).banner, isNull);
      expect(AppConfig.fromJson(banner({'id': ''})).banner, isNull);
      // Only one language written: everyone reads that one.
      final enOnly = AppConfig.fromJson(
        banner({
          'bn': {'title': '', 'body': ''},
        }),
      ).banner!;
      expect(enOnly.inLanguage(AppLanguage.bn).title, 'Update');
    });

    test('blocked words are found in any case, anywhere, in either script', () {
      final w = BlockedWords.fromJson({
        'words': ['t.me/', 'vip signal', 'টেলিগ্রাম'],
      });
      expect(w.firstIn('Join our VIP SIGNAL group'), 'vip signal');
      expect(w.firstIn('more at\nT.ME/abc'), 't.me/');
      expect(w.firstIn('আমাদের টেলিগ্রামে আসুন'), 'টেলিগ্রাম');
      expect(w.firstIn('EUR/USD long, stop below 1.0850'), isNull);
      expect(BlockedWords.none.firstIn('anything'), isNull);
      expect(BlockedWords.fromJson(null).words, isEmpty);
    });
  });

  test('the build number is the one in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final build = RegExp(
      r'^version:\s*\S+\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appBuild, int.parse(build!));
  });

  group('on screen', () {
    late StreamController<AppConfig> config;
    late StreamController<BlockedWords> words;

    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      int build = 5,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final auth = LocalAuthRepository(
        prefs: await SharedPreferences.getInstance(),
      );
      await auth.signUp(
        username: 'tester',
        password: 'secret123',
        displayName: 'Tester',
        gender: Gender.male,
        language: AppLanguage.en,
        avatarId: 1,
      );
      final session = SessionController(auth);
      await session.restore();
      config = StreamController<AppConfig>();
      words = StreamController<BlockedWords>();
      await tester.pumpWidget(
        SessionScope(
          controller: session,
          child: AppConfigHost(
            app: config.stream,
            blocked: words.stream,
            child: MaterialApp(
              theme: buildAppTheme(),
              builder: (context, inner) =>
                  AppGate(thisBuild: build, child: inner!),
              home: child,
            ),
          ),
        ),
      );
    }

    testWidgets('maintenance closes the app over everything; reopened, it is '
        'where it was', (tester) async {
      await pump(tester, const Scaffold(body: Text('the app')));
      expect(find.text('the app'), findsOneWidget);

      config.add(
        AppConfig.fromJson({
          'maintenance': {'on': true, 'en': 'Back at 10 pm'},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back soon'), findsOneWidget);
      expect(find.text('Back at 10 pm'), findsOneWidget);
      expect(find.text('the app'), findsNothing);

      config.add(AppConfig.none);
      await tester.pumpAndSettle();
      expect(find.text('the app'), findsOneWidget);
      expect(find.text('Back soon'), findsNothing);
    });

    testWidgets('an old build is told to update, with the link to copy', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: Text('the app')), build: 2);
      config.add(
        AppConfig.fromJson({'minBuild': 2, 'updateUrl': 'https://get.app'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('the app'), findsOneWidget, reason: 'build 2 is fine');

      config.add(
        AppConfig.fromJson({'minBuild': 3, 'updateUrl': 'https://get.app'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update the app'), findsOneWidget);
      expect(find.text('https://get.app'), findsOneWidget);
      expect(find.text('the app'), findsNothing);
    });

    testWidgets('a banner over the app until closed; closed stays closed, a '
        'new one shows', (tester) async {
      await pump(
        tester,
        const Scaffold(body: AppBannerFrame(child: Text('the app'))),
      );
      Map<String, dynamic> banner(String id) => {
        'banner': {
          'on': true,
          'id': id,
          'bn': {'title': 'খবর'},
          'en': {'title': 'News for you', 'body': 'Read me'},
        },
      };
      config.add(AppConfig.fromJson(banner('b1')));
      await tester.pumpAndSettle();
      expect(find.text('News for you'), findsOneWidget);
      expect(find.text('the app'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('News for you'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString('banner.closed'),
        'b1',
      );

      config.add(AppConfig.fromJson(banner('b1')));
      await tester.pumpAndSettle();
      expect(find.text('News for you'), findsNothing);
      config.add(AppConfig.fromJson(banner('b2')));
      await tester.pumpAndSettle();
      expect(find.text('News for you'), findsOneWidget);
    });
  });
}
