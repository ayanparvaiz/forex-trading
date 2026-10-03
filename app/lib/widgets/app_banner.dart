import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/session_controller.dart';
import '../models/app_config.dart';
import '../theme/app_theme.dart';
import 'app_config_host.dart';

/// The admins' banner across the top of the app, over every tab, until
/// it is closed. Closing remembers that banner only: a new one shows again.
class AppBannerFrame extends StatefulWidget {
  const AppBannerFrame({super.key, required this.child});

  final Widget child;

  static const _closedKey = 'banner.closed';

  @override
  State<AppBannerFrame> createState() => _AppBannerFrameState();
}

class _AppBannerFrameState extends State<AppBannerFrame> {
  /// The banner closed on this phone, once known.
  String? _closed;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _closed = p.getString(AppBannerFrame._closedKey);
        _loaded = true;
      });
    });
  }

  Future<void> _close(String id) async {
    setState(() => _closed = id);
    await (await SharedPreferences.getInstance()).setString(
      AppBannerFrame._closedKey,
      id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = AppConfigScope.configOf(context).banner;
    if (!_loaded || banner == null || banner.id == _closed) return widget.child;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: _Banner(banner: banner, onClose: () => _close(banner.id)),
        ),
        // The tabs below keep their own safe area for the bottom only.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.banner, required this.onClose});

  final AppBanner banner;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final notice = banner.inLanguage(s.lang);
    final color = banner.warning ? AppColors.warning : AppColors.brand;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.xs, Gap.md),
      decoration: BoxDecoration(
        color: banner.warning ? AppColors.warningDim : AppColors.brandDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              banner.warning
                  ? Icons.warning_amber_rounded
                  : Icons.campaign_outlined,
              size: 20,
              color: color,
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (notice.body.isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    notice.body,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: s.closeNotice,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
