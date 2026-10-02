import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/price_alerts.dart';
import '../data/session_controller.dart';
import '../models/instrument.dart';
import '../theme/app_theme.dart';

/// Setting a price alert on [instrument], which is at [current] now — and
/// the alerts already set, to take down.
Future<void> showPriceAlertSheet(
  BuildContext context, {
  required Instrument instrument,
  required double current,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _PriceAlertSheet(instrument: instrument, current: current),
);

class _PriceAlertSheet extends StatefulWidget {
  const _PriceAlertSheet({required this.instrument, required this.current});

  final Instrument instrument;
  final double current;

  @override
  State<_PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends State<_PriceAlertSheet> {
  // Twenty pips above the price, a typical place to want to hear about.
  late final _price = TextEditingController(
    text: widget.instrument.formatPrice(
      widget.instrument.shiftByPips(widget.current, 20),
    ),
  );

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _nudge(double pips) {
    final now = double.tryParse(_price.text) ?? widget.current;
    _price.text = widget.instrument.formatPrice(
      widget.instrument.shiftByPips(now, pips),
    );
    setState(() {});
  }

  Future<void> _set() async {
    final s = context.s;
    final price = double.tryParse(_price.text);
    if (price == null || price <= 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await priceAlerts.add(
      widget.instrument.symbol,
      price,
      widget.current,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? s.alertSet(
                  widget.instrument.symbol,
                  widget.instrument.formatPrice(price),
                )
              : s.tooManyAlerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final i = widget.instrument;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
        child: ListenableBuilder(
          listenable: priceAlerts,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.priceAlerts,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Gap.h4,
              Text(
                s.alertsWhileOpen,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              Gap.h16,
              Text(
                s.alertWhen(i.symbol),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Gap.h8,
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: () => _nudge(-10),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Gap.w8,
                  Expanded(
                    child: TextField(
                      controller: _price,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  Gap.w8,
                  IconButton.outlined(
                    onPressed: () => _nudge(10),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              Gap.h12,
              FilledButton.icon(
                onPressed: _set,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(s.alertMe),
              ),
              Gap.h16,
              if (priceAlerts.alerts.isEmpty)
                Text(
                  s.noAlerts,
                  style: const TextStyle(color: AppColors.textMuted),
                )
              else
                for (final a in priceAlerts.alerts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      a.above
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: a.above ? AppColors.profit : AppColors.loss,
                    ),
                    title: Text(
                      '${a.symbol}  ${Instrument.bySymbol(a.symbol).formatPrice(a.price)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => priceAlerts.remove(a.id),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
