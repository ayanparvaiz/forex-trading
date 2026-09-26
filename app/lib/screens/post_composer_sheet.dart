import 'package:flutter/material.dart';

import '../data/communities_repository.dart';
import '../data/community_repository.dart';
import '../data/feed_scope.dart';
import '../data/push_notifier.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/community.dart';
import '../models/instrument.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feed_picker.dart';

/// A leaderboard position, captured before the sheet opens.
///
/// Passed in rather than looked up here, because the number the author is
/// sharing is the one they were looking at when they tapped — not whatever the
/// board says by the time the sheet has finished animating.
class RankShare {
  const RankShare({
    required this.rank,
    required this.score,
    required this.badgeEmoji,
  });

  final int rank;
  final double score;
  final String badgeEmoji;
}

/// Writes a post: from scratch, from a closed trade, or from a leaderboard row.
///
/// One composer for all three. Sharing a trade fills in the pair, the result
/// and the reasoning that were already recorded — but the lesson is always
/// typed here, because a lesson written at the moment of sharing is a different
/// and better sentence than one written at the moment of closing.
///
/// It goes to [scope] — Global, or the author's community — which the author
/// can change here; without one, to the feed they last chose. Returns the
/// feed it was posted to, or null if nothing was.
Future<String?> showPostComposer(
  BuildContext context, {
  required CommunityRepository repository,
  Trade? trade,
  RankShare? rank,
  String? scope,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    // Keeps the sheet clear of the notch and the home indicator, and gives it
    // a real maximum height to size itself against.
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _Composer(
      repository: repository,
      trade: trade,
      rank: rank,
      scope: scope,
    ),
  );
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.repository,
    this.trade,
    this.rank,
    this.scope,
  });

  final CommunityRepository repository;
  final Trade? trade;
  final RankShare? rank;
  final String? scope;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late String _symbol = widget.trade?.symbol ?? Instrument.all.first.symbol;
  late double _r = widget.trade?.rMultiple ?? 1.0;
  late final _reason = TextEditingController(text: widget.trade?.reason ?? '');
  final _lesson = TextEditingController();

  /// Taken from the trade rather than asked, because the app already knows.
  /// Claiming you followed your rules when the record says otherwise is not a
  /// checkbox anyone should get.
  late final bool _followedRules = widget.trade?.violations.isEmpty ?? true;

  bool _posting = false;

  /// Where it goes. Null only while the last choice is read from the phone.
  String? _scope;
  final _scopes = FeedScope();

  /// The author's community, for its name.
  Community? _community;
  bool _started = false;

  bool get _fromTrade => widget.trade != null;
  bool get _fromRank => widget.rank != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final session = context.session;
    final uid = session.uid;
    final communityId = session.profile?.communityId;
    if (widget.scope != null || uid == null) {
      _scope = FeedScope.valid(widget.scope, communityId);
    } else {
      _scopes.load(uid, communityId).then((scope) {
        if (mounted) setState(() => _scope ??= scope);
      });
    }
    if (communityId != null) {
      buildCommunitiesRepository()?.watch(communityId).first.then((c) {
        if (mounted) setState(() => _community = c);
      }, onError: (_) {});
    }
  }

  Future<void> _pickScope() async {
    final session = context.session;
    final uid = session.uid;
    final picked = await pickFeed(
      context,
      current: _scope ?? FeedScope.global,
      communityId: session.profile?.communityId,
      community: _community,
    );
    if (picked == null || !mounted) return;
    setState(() => _scope = picked);
    if (uid != null) _scopes.save(uid, picked);
  }

  @override
  void dispose() {
    _reason.dispose();
    _lesson.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _lesson.text.trim().length >= 10 &&
      (_fromRank || _reason.text.trim().isNotEmpty) &&
      _scope != null &&
      !_posting;

  Future<void> _publish() async {
    final session = context.session;
    final me = session.profile;
    final uid = session.uid;
    if (me == null || uid == null) return;

    setState(() => _posting = true);

    final scope = _scope ?? FeedScope.global;
    final shared = widget.rank;
    final id = shared != null
        ? await widget.repository.createRankPost(
            uid: uid,
            username: me.username,
            rank: shared.rank,
            score: shared.score,
            lesson: _lesson.text,
            community: scope,
          )
        : await widget.repository.createPost(
            uid: uid,
            username: me.username,
            symbol: _symbol,
            rMultiple: _r,
            reason: _reason.text,
            lesson: _lesson.text,
            followedRules: _followedRules,
            community: scope,
          );

    // Connections hear about it on their phones.
    if (id != null) pushNotifier?.post(id);

    if (!mounted) return;
    setState(() => _posting = false);
    Navigator.of(context).pop(id == null ? null : scope);
  }

  String _title(Strings s) {
    if (_fromRank) return s.shareYourRank;
    return _fromTrade ? s.shareToFeed : s.newPost;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    // The sheet is lifted by the keyboard rather than squeezed under it. The
    // body is the only flexible part, so as the keyboard grows it is the list
    // that shrinks — the heading stays put and the post button stays reachable
    // instead of ending up behind the keys.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
            child: Row(
              children: [
                Text(_title(s), style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          _Destination(
            scope: _scope,
            community: _community,
            onTap: context.session.profile?.communityId == null
                ? null
                : _pickScope,
          ),
          const Divider(height: 1),
          Flexible(child: _body(s)),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.md,
              ),
              // Listens to the controllers instead of rebuilding the form on
              // every keystroke. The button is the only thing typing changes,
              // so the button is the only thing that should be rebuilt by it.
              child: ListenableBuilder(
                listenable: Listenable.merge([_reason, _lesson]),
                builder: (context, _) => FilledButton(
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
          ),
        ],
      ),
    );
  }

  Widget _body(Strings s) {
    final shared = widget.rank;

    // A scrolling Column, never a ListView.
    //
    // ListView builds lazily and throws its children away once they leave the
    // viewport — which for a form means the field being typed into can be
    // disposed out from under the keyboard the moment the layout shifts, and
    // its connection to the platform's text input goes with it. That is what
    // eats characters: a letter or two arrives, the field is rebuilt, and the
    // rest go nowhere. A form is a fixed, short list of controls that all have
    // to stay alive, so every one of them is built up front.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shared != null)
            _RankSummary(share: shared, s: s)
          else if (_fromTrade)
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
                    onSelected: (_) => setState(() => _symbol = i.symbol),
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

          // A rank post has no trade behind it, so there is nothing to ask why
          // about. The one line it does carry is how the author got there.
          if (!_fromRank) ...[
            Gap.h16,
            Text(s.whyITookIt, style: Theme.of(context).textTheme.labelSmall),
            Gap.h8,
            TextField(
              // Keyed so the field keeps its element, and with it its focus and
              // its selection, when the list around it changes shape.
              key: const ValueKey('composer.reason'),
              controller: _reason,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14, height: 1.45),
              decoration: InputDecoration(hintText: s.whyHint),
            ),
          ],

          Gap.h16,
          Text(
            _fromRank ? s.howYouGotHere : s.whatILearned,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Gap.h8,
          TextField(
            key: const ValueKey('composer.lesson'),
            controller: _lesson,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14, height: 1.45),
            decoration: InputDecoration(
              hintText: _fromRank ? s.howYouGotHereHint : s.lessonHint,
              helperText: s.lessonRequiredToPost,
              helperMaxLines: 2,
              helperStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
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
                    _fromRank ? s.rankPostGuideline : s.postGuideline,
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
    );
  }
}

/// The leaderboard position being shared, shown rather than re-entered.
/// Where the post will go, under the heading — and, for someone in a
/// community, the way to send it to the other feed.
class _Destination extends StatelessWidget {
  const _Destination({required this.scope, this.community, this.onTap});

  final String? scope;
  final Community? community;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final where = scope;
    final name = where == null
        ? '…'
        : where == FeedScope.global
        ? s.globalChat
        : community?.name ?? '…';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
        child: Row(
          children: [
            Icon(
              where == null || where == FeedScope.global
                  ? Icons.public_rounded
                  : Icons.groups_2_outlined,
              size: 16,
              color: AppColors.brand,
            ),
            Gap.w8,
            Flexible(
              child: Text(
                s.postingTo(name),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _RankSummary extends StatelessWidget {
  const _RankSummary({required this.share, required this.s});

  final RankShare share;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.disciplineDim,
        borderRadius: Radii.tile,
        border: Border.all(color: AppColors.discipline.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(
            '#${share.rank}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: tabularFigures,
              color: AppColors.discipline,
            ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.leaderboard,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${s.discipline} ${share.score.toStringAsFixed(0)} · '
                  '${s.gradeFor(share.score)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          Text(share.badgeEmoji, style: const TextStyle(fontSize: 22)),
        ],
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
