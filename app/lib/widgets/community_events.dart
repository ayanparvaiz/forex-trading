import 'dart:async';

import 'package:flutter/material.dart';

import '../data/communities_repository.dart';
import '../data/push_notifier.dart';
import '../data/session_controller.dart';
import '../models/community.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// A community's events, for its members: what is coming up, who is going,
/// and — for its admin — planning the next one.
class CommunityEvents extends StatefulWidget {
  const CommunityEvents({
    super.key,
    required this.community,
    required this.isAdmin,
  });

  final Community community;
  final bool isAdmin;

  @override
  State<CommunityEvents> createState() => _CommunityEventsState();
}

class _CommunityEventsState extends State<CommunityEvents> {
  final _repo = buildCommunitiesRepository();
  StreamSubscription<List<CommunityEvent>>? _following;
  List<CommunityEvent>? _events;

  @override
  void initState() {
    super.initState();
    _following = _repo
        ?.watchEvents(widget.community.id)
        .listen(
          (e) => setState(() => _events = e),
          onError: (Object e) => debugPrint('events failed: $e'),
        );
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  Future<void> _plan() async {
    final repo = _repo;
    final uid = context.session.uid;
    if (repo == null || uid == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final plan = await showDialog<(String, String, DateTime)>(
      context: context,
      builder: (_) => const _PlanDialog(),
    );
    if (plan == null) return;
    try {
      final id = await repo.createEvent(
        id: widget.community.id,
        me: uid,
        title: plan.$1,
        description: plan.$2,
        startsAt: plan.$3,
      );
      pushNotifier?.event(widget.community.id, id);
      messenger.showSnackBar(SnackBar(content: Text(s.eventPlanned)));
    } catch (e) {
      debugPrint('plan failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  Future<void> _going(CommunityEvent e, bool going) async {
    final uid = context.session.uid;
    if (_repo == null || uid == null) return;
    try {
      await _repo.setGoing(
        id: widget.community.id,
        eventId: e.id,
        uid: uid,
        going: going,
      );
    } catch (err) {
      debugPrint('going failed: $err');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.s.couldNotSave)));
      }
    }
  }

  Future<void> _delete(CommunityEvent e) async {
    try {
      await _repo?.deleteEvent(widget.community.id, e.id);
    } catch (err) {
      debugPrint('delete event failed: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final events = _events;
    final uid = context.session.uid;
    return SectionCard(
      title: s.eventsHeading,
      trailing: widget.isAdmin
          ? TextButton.icon(
              onPressed: _plan,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s.newEvent),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
      child: events == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : events.isEmpty
          ? Text(
              widget.isAdmin ? s.noEventsAdmin : s.noEvents,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            )
          : Column(
              children: [
                for (final e in events)
                  _EventTile(
                    event: e,
                    going: uid != null && e.going.contains(uid),
                    onGoing: (g) => _going(e, g),
                    onDelete: widget.isAdmin ? () => _delete(e) : null,
                  ),
              ],
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.going,
    required this.onGoing,
    this.onDelete,
  });

  final CommunityEvent event;
  final bool going;
  final ValueChanged<bool> onGoing;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final e = event;
    final local = e.startsAt.toLocal();
    final now = DateTime.now();
    final happening = e.happeningAt(now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The day, as a calendar leaf.
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: happening ? AppColors.brandDim : AppColors.elevated,
              borderRadius: Radii.tile,
            ),
            child: Column(
              children: [
                Text(
                  '${local.day}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  s.shortDate(local).split(' ').last,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // Wraps on a narrow phone rather than spill.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Gap.sm,
                  runSpacing: 2,
                  children: [
                    Text(
                      s.clock(local),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (happening)
                      Pill(
                        text: s.happeningNow,
                        color: AppColors.profit,
                        dense: true,
                      ),
                    Text(
                      s.goingCount(e.going.length),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (e.description.isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    e.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                Gap.h8,
                Row(
                  children: [
                    going
                        ? FilledButton.icon(
                            onPressed: () => onGoing(false),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(s.going),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 32),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: () => onGoing(true),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 32),
                            ),
                            child: Text(s.going),
                          ),
                    const Spacer(),
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        tooltip: s.deleteEvent,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What, when, and a few words about it. The answer, or null.
class _PlanDialog extends StatefulWidget {
  const _PlanDialog();

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late DateTime _when = _nextRoundHour();

  static DateTime _nextRoundHour() {
    final now = DateTime.now().add(const Duration(hours: 2));
    return DateTime(now.year, now.month, now.day, now.hour);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _titleFits =>
      _title.text.trim().length >= CommunityEvent.titleMin &&
      _title.text.trim().length <= CommunityEvent.titleMax;

  bool get _inFuture => _when.isAfter(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (day == null) return;
    setState(
      () => _when = DateTime(
        day.year,
        day.month,
        day.day,
        _when.hour,
        _when.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(
      () => _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      backgroundColor: AppColors.elevated,
      title: Text(s.newEvent),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: CommunityEvent.titleMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.eventTitle),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: CommunityEvent.descriptionMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: s.eventDescriptionHint),
            ),
            Gap.h8,
            Text(s.eventWhen, style: Theme.of(context).textTheme.labelSmall),
            Gap.h4,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(s.shortDate(_when)),
                  ),
                ),
                Gap.w8,
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(s.clock(_when)),
                  ),
                ),
              ],
            ),
            if (!_inFuture) ...[
              Gap.h8,
              Text(
                s.eventInPast,
                style: const TextStyle(fontSize: 12.5, color: AppColors.loss),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: _titleFits && _inFuture
              ? () => Navigator.of(
                  context,
                ).pop((_title.text.trim(), _description.text.trim(), _when))
              : null,
          child: Text(s.planAction),
        ),
      ],
    );
  }
}
