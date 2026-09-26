import 'dart:async';

import 'package:flutter/material.dart';

import '../data/communities_repository.dart';
import '../data/session_controller.dart';
import '../models/community.dart';
import '../theme/app_theme.dart';
import 'community_profile_screen.dart';

/// Opens the form for a new community.
Future<void> openStartCommunity(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const StartCommunityScreen()));

/// Starting a community: a name nobody has, and a few words about it.
///
/// Whoever starts it is its admin, and it opens with its own chat room. The
/// name is checked while it is typed, so a taken one is said before Start
/// rather than after.
class StartCommunityScreen extends StatefulWidget {
  const StartCommunityScreen({super.key});

  @override
  State<StartCommunityScreen> createState() => _StartCommunityScreenState();
}

class _StartCommunityScreenState extends State<StartCommunityScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _repo = buildCommunitiesRepository();

  /// The name the one you are in goes by — starting one leaves it.
  String? _leavingName;
  bool _started = false;

  /// Whether the name in the box is free: null while unknown.
  bool? _available;
  Timer? _debounce;

  /// Bumped per check, so a slow answer never speaks for a newer name.
  int _asked = 0;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final current = context.session.profile?.communityId;
    if (current == null || _repo == null) return;
    _repo.watch(current).first.then((c) {
      if (mounted) setState(() => _leavingName = c?.name);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _tidy => Community.tidyName(_name.text);

  bool get _nameFits =>
      _tidy.length >= Community.nameMin && _tidy.length <= Community.nameMax;

  bool get _canStart => !_busy && _nameFits && _available != false;

  void _nameChanged(String _) {
    _debounce?.cancel();
    final asked = ++_asked;
    setState(() => _available = null);
    if (!_nameFits || _repo == null) return;
    final name = _tidy;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final free = await _repo.nameAvailable(name);
        if (mounted && asked == _asked) setState(() => _available = free);
      } catch (_) {
        // Unknown: Start will find out.
      }
    });
  }

  Future<void> _start() async {
    final repo = _repo;
    final session = context.session;
    final profile = session.profile;
    final uid = session.uid;
    if (repo == null || profile == null || uid == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final name = _tidy;
    setState(() => _busy = true);
    try {
      final id = await repo.create(
        me: uid,
        username: profile.username,
        name: name,
        description: _description.text,
        leaving: profile.communityId,
      );
      session.setCommunity(id);
      messenger.showSnackBar(SnackBar(content: Text(s.communityCreated(name))));
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => CommunityProfileScreen(id: id)),
      );
    } on CommunityNameTaken {
      if (mounted) {
        setState(() {
          _busy = false;
          _available = false;
        });
      }
    } catch (e) {
      debugPrint('start community failed: $e');
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final leaving = _leavingName;
    return Scaffold(
      appBar: AppBar(title: Text(s.startCommunity)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.startCommunityBody,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            Gap.h24,
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: Community.nameMax,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: _nameChanged,
              decoration: InputDecoration(
                labelText: s.communityName,
                helperText: s.communityNameRule,
                errorText: _available == false ? s.communityNameTaken : null,
                prefixIcon: const Icon(Icons.groups_2_outlined, size: 20),
                suffixIcon: _available == true
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.profit,
                        size: 20,
                      )
                    : null,
              ),
            ),
            Gap.h12,
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              maxLength: Community.descriptionMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: s.communityDescriptionHint,
                alignLabelWithHint: true,
              ),
            ),
            if (leaving != null) ...[
              Gap.h12,
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: AppColors.warning,
                  ),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      s.startLeaves(leaving),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            Gap.h24,
            FilledButton(
              onPressed: _canStart ? _start : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(s.startAction),
            ),
          ],
        ),
      ),
    );
  }
}
