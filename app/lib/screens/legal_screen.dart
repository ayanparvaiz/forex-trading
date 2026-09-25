import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../legal/legal_text.dart';
import '../theme/app_theme.dart';

enum LegalPage { privacy, terms }

Future<void> openLegal(BuildContext context, LegalPage page) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => LegalScreen(page: page)));

/// The privacy policy or the terms, in the app itself.
///
/// In the app rather than behind a link, so it opens offline, in the reader's
/// language, and says the same thing whichever version of the app they have.
/// It follows the app's language, and works before sign-in too — the sign-up
/// screen links here.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});

  final LegalPage page;

  @override
  Widget build(BuildContext context) {
    final lang = context.session.language;
    final doc = page == LegalPage.privacy
        ? privacyPolicy(lang)
        : termsOfUse(lang);

    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
          children: [
            Text(
              doc.updated,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
            Gap.h12,
            Text(doc.intro, style: _body),
            for (final section in doc.sections) ...[
              Gap.h24,
              Text(
                section.heading,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Gap.h8,
              for (final line in section.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: line.startsWith('• ')
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 8, right: 10),
                              child: CircleAvatar(
                                radius: 2.5,
                                backgroundColor: AppColors.brand,
                              ),
                            ),
                            Expanded(
                              child: Text(line.substring(2), style: _body),
                            ),
                          ],
                        )
                      : Text(line, style: _body),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static const _body = TextStyle(
    fontSize: 14.5,
    height: 1.6,
    color: AppColors.textSecondary,
  );
}
