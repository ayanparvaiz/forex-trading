import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_scope.dart';
import '../data/account_store.dart';
import '../data/price_alerts.dart';
import '../data/session_controller.dart';
import '../models/instrument.dart';
import '../theme/app_theme.dart';

/// Watches the practice market for price alerts, above every screen, and
/// rings them as a banner across the top — with a buzz, since a price is
/// worth looking up for.
class PriceAlertHost extends StatefulWidget {
  const PriceAlertHost({super.key, required this.child});

  final Widget child;

  @override
  State<PriceAlertHost> createState() => _PriceAlertHostState();
}

class _PriceAlertHostState extends State<PriceAlertHost> {
  AccountStore? _store;
  String? _uid;
  late final StreamSubscription<PriceAlert> _rang;
  PriceAlert? _banner;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _rang = priceAlerts.rang.listen(_show);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not a dependency on the store: it ticks every second, and this only
    // needs to listen, not rebuild.
    final store = context
        .getInheritedWidgetOfExactType<AccountScope>()
        ?.notifier;
    if (store != _store) {
      _store?.removeListener(_check);
      _store = store?..addListener(_check);
    }
    final uid = SessionScope.of(context).uid;
    if (uid != _uid) {
      _uid = uid;
      priceAlerts.load(uid);
    }
  }

  void _check() {
    final market = _store?.market;
    if (market == null || priceAlerts.alerts.isEmpty) return;
    priceAlerts.check((symbol) => market.price(Instrument.bySymbol(symbol)));
  }

  void _show(PriceAlert alert) {
    HapticFeedback.mediumImpact();
    _hide?.cancel();
    if (mounted) setState(() => _banner = alert);
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  void dispose() {
    _store?.removeListener(_check);
    _rang.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: banner == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(banner.id),
                      padding: const EdgeInsets.fromLTRB(
                        Gap.sm,
                        Gap.xs,
                        Gap.sm,
                        0,
                      ),
                      child: Material(
                        color: AppColors.warning,
                        elevation: 8,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => setState(() => _banner = null),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.md),
                            child: Text(
                              context.s.alertReached(
                                banner.symbol,
                                Instrument.bySymbol(
                                  banner.symbol,
                                ).formatPrice(banner.price),
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.bg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
