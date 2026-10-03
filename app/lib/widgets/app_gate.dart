import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/build_info.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import 'app_config_host.dart';

/// In front of the whole app, sign-in included: while the admins have it
/// closed for maintenance, or when this build is older than they allow, a
/// screen saying so — and nothing behind it can be used. The app stays
/// where it was underneath, so it carries on as it was when they reopen it.
class AppGate extends StatelessWidget {
  const AppGate({super.key, required this.child, this.thisBuild = appBuild});

  final Widget child;

  /// This build's number; a test gives another.
  final int thisBuild;

  @override
  Widget build(BuildContext context) {
    final config = AppConfigScope.configOf(context);
    final Widget? gate = config.maintenance != null
        ? _Maintenance(
            message:
                config.maintenance!.message(context.s.lang) ??
                context.s.maintenanceDefault,
          )
        : config.needsUpdate(thisBuild)
        ? _Update(url: config.updateUrl)
        : null;
    return Stack(
      children: [
        Offstage(offstage: gate != null, child: child),
        ?gate,
      ],
    );
  }
}

class _GateScreen extends StatelessWidget {
  const _GateScreen({
    required this.icon,
    required this.title,
    required this.message,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.elevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: AppColors.brand),
                ),
                Gap.h24,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Gap.h12,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (extra != null) ...[Gap.h24, extra!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Maintenance extends StatelessWidget {
  const _Maintenance({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _GateScreen(
    icon: Icons.construction_rounded,
    title: context.s.maintenanceTitle,
    message: message,
  );
}

class _Update extends StatefulWidget {
  const _Update({required this.url});

  final String url;

  @override
  State<_Update> createState() => _UpdateState();
}

class _UpdateState extends State<_Update> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return _GateScreen(
      icon: Icons.system_update_rounded,
      title: s.updateTitle,
      message: s.updateBody,
      extra: widget.url.isEmpty
          ? null
          : Column(
              children: [
                SelectableText(
                  widget.url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.brand),
                ),
                Gap.h12,
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.url));
                    if (mounted) setState(() => _copied = true);
                  },
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                  ),
                  label: Text(_copied ? s.linkCopied : s.copyLink),
                ),
              ],
            ),
    );
  }
}
