import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/instrument.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Writes a post, either from scratch or prefilled from a closed trade.
///
/// One composer for both routes. Sharing a trade is the common case and fills
/// in the pair, the result and the reasoning that were already recorded — but
/// the lesson is always typed here, because a lesson written at the moment of
/// sharing is a different and better sentence than one written at the moment
/// of closing.
Future<bool> showPostComposer(
  BuildContext context, {
  required CommunityRepository repository,
  Trade? trade,
}) async {
  final posted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _Composer(repository: repository, trade: trade),
  );
  return posted ?? false;
}

class _Composer extends StatefulWidget {
  const _Composer({required this.repository, this.trade});

  final CommunityRepository repository;
  final Trade? trade;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late String _symbol = widget.trade?.symbol ?? Instrument.all.first.symbol;
  late double _r = widget.trade?.rMultiple ?? 1.0;
  late final _reason = TextEditingController(text: widget.trade?.reason ?? '');
  late final _lesson = TextEditingController(text: widget.trade?.lesson ?? '');

  /// Taken from the trade rather than asked, because the app already knows.
  /// Claiming you followed your rules when the record says otherwise is not a
  /// checkbox anyone should get.
  late final bool _followedRules = widget.trade?.violations.isEmpty ?? true;

  bool _posting = false;

  bool get _fromTrade => widget.trade != null;

  @override
  void dispose() {
    _reason.dispose();
    _lesson.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _lesson.text.trim().length >= 10 &&
      _reason.text.trim().isNotEmpty &&
      !_posting;

  Future<void> _publish() async {
    final session = context.session;
    final me = session.profile;
    final uid = session.uid;
    if (me == null || uid == null) return;

    setState(() => _posting = true);

    final id = await widget.repository.createPost(
      uid: uid,
      username: me.username,
      symbol: _symbol,
      rMultiple: _r,
      reason: _reason.text,
      lesson: _lesson.text,
      followedRules: _followedRules,
    );

    if (!mounted) return;
    setState(() => _posting = false);
    Navigator.of(context).pop(id != null);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.94,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
              child: Row(
                children: [
                  Text(
                    _fromTrade ? s.shareToFeed : s.newPost,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
                children: [
                  if (_fromTrade)
                    _TradeSummary(trade: widget.trade!, s: s)
                  else ...[
                    Text(s.pair, style: Theme.of(context).textTheme.labelSmall),
                    Gap.h8,
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final i in Instrument.all)
                          ChoiceChip(
                            label: Text(i.symbol),
                            selected: _symbol == i.symbol,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _symbol = i.symbol),
                            backgroundColor: AppColors.elevated,
                            selectedColor: AppColors.brandDim,
                            side: BorderSide(
                              color: _symbol == i.symbol
                                  ? AppColors.brand
                                  : AppColors.border,
                            ),
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    Gap.h16,
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.result,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        Text(
                          rMultiple(_r),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFeatures: tabularFigures,
                            color: AppColors.forValue(_r),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _r.clamp(-5, 10),
                      min: -5,
                      max: 10,
                      divisions: 150,
                      onChanged: (v) => setState(() => _r = v),
                    ),
                    Gap.h8,
                  ],
                  Gap.h16,
                  Text(
                    s.whyITookIt,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Gap.h8,
                  TextField(
                    controller: _reason,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                    decoration: InputDecoration(hintText: s.whyHint),
                    onChanged: (_) => setState(() {}),
                  ),
                  Gap.h16,
                  Text(
                    s.whatILearned,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Gap.h8,
                  TextField(
                    controller: _lesson,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                    decoration: InputDecoration(
                      hintText: s.lessonHint,
                      helperText: s.lessonRequiredToPost,
                      helperMaxLines: 2,
                      helperStyle: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  Gap.h16,
                  Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: Radii.tile,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        Gap.w8,
                        Expanded(
                          child: Text(
                            s.postGuideline,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
                child: FilledButton(
                  onPressed: _canPost ? _publish : null,
                  child: _posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(s.publish),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The trade being shared, shown rather than re-entered.
class _TradeSummary extends StatelessWidget {
  const _TradeSummary({required this.trade, required this.s});

  final Trade trade;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final r = trade.rMultiple ?? 0;
    final clean = trade.violations.isEmpty;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: Radii.tile,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            rMultiple(r),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              fontFeatures: tabularFigures,
              color: AppColors.forValue(r),
            ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade.symbol,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${trade.riskPips.toStringAsFixed(0)} ${s.pips} · '
                  '${trade.lots.toStringAsFixed(2)} ${s.lots}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          // Read from the record, not asked. Whether the rules were kept is
          // already known, and it is not a claim anyone gets to make freely.
          Pill(
            text: clean ? s.followedRules : s.brokeRules,
            color: clean ? AppColors.profit : AppColors.loss,
            icon: clean ? Icons.verified_outlined : Icons.error_outline,
            dense: true,
          ),
        ],
      ),
    );
  }
}
