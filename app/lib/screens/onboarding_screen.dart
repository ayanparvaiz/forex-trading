import 'package:flutter/material.dart';

import '../data/one_time_notice.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';

/// Shows the tour if this phone has not seen it yet.
Future<void> maybeShowTour(
  BuildContext context, {
  OneTimeNotice? notice,
}) async {
  final seen = notice ?? OneTimeNotice(OnboardingScreen.noticeId);
  if (await seen.isDismissed() || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const OnboardingScreen(),
    ),
  );
  await seen.dismiss();
}

/// What the app is for, in four pages — once, the first time it opens on a
/// phone. Skippable from the first page: nobody should have to read a tour
/// to use an app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Changing it shows the tour again to everyone, for when it says
  /// something new.
  static const noticeId = 'onboarding.tour.v1';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final pages = [
      (
        Icons.candlestick_chart_rounded,
        AppColors.brand,
        s.tourPracticeTitle,
        s.tourPracticeBody,
      ),
      (
        Icons.shield_outlined,
        AppColors.discipline,
        s.tourDisciplineTitle,
        s.tourDisciplineBody,
      ),
      (
        Icons.groups_rounded,
        AppColors.warning,
        s.tourCommunityTitle,
        s.tourCommunityBody,
      ),
      (
        Icons.menu_book_rounded,
        AppColors.profit,
        s.tourJournalTitle,
        s.tourJournalBody,
      ),
    ];
    final last = _page == pages.length - 1;
    void done() => Navigator.of(context).pop();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: done,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
                child: Text(s.tourSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (icon, color, title, body) in pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.14),
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(icon, size: 56, color: color),
                          ),
                          Gap.h32,
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          Gap.h12,
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.brand : AppColors.border,
                      borderRadius: Radii.pill,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.xl,
                Gap.lg,
                Gap.xl,
                Gap.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? done
                      : () => _pages.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        ),
                  child: Text(last ? s.tourStart : s.tourNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
