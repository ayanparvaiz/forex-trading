import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/communities_repository.dart';
import '../data/community_avatars.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/community.dart';
import '../theme/app_theme.dart';
import 'chat_bits.dart';
import 'conversation_view.dart';

/// A community's picture: the one it chose, as a rounded square.
///
/// Rounded square rather than round, so a community never looks like a
/// person in a list of people. One from before pictures shows its initial on
/// a colour taken from its id, so it looks the same wherever it shows up.
class CommunityBadge extends StatelessWidget {
  const CommunityBadge({
    super.key,
    required this.id,
    required this.name,
    this.avatarId,
    this.size = 48,
  });

  final String id;
  final String name;
  final int? avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final picture = CommunityAvatars.byId(avatarId);
    if (picture != null) {
      return SvgPicture.asset(
        picture.asset,
        width: size,
        height: size,
        semanticsLabel: name,
        // A fixed box keeps rows from jumping while the file is parsed.
        placeholderBuilder: (_) => SizedBox.square(dimension: size),
      );
    }
    final color = senderColor(id);
    final initial = name.trim().isEmpty
        ? '#'
        : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.45)!],
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// Community [id]'s picture, followed live — for a place that knows the
/// community only by its room. The last one seen is remembered, so a row
/// drawn again does not flash the initial first.
class LiveCommunityBadge extends StatefulWidget {
  const LiveCommunityBadge({
    super.key,
    required this.id,
    required this.name,
    this.size = 48,
  });

  final String id;
  final String name;
  final double size;

  @override
  State<LiveCommunityBadge> createState() => _LiveCommunityBadgeState();
}

class _LiveCommunityBadgeState extends State<LiveCommunityBadge> {
  static final _seen = <String, int?>{};

  StreamSubscription<Community?>? _following;
  int? _avatarId;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(LiveCommunityBadge old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _follow();
  }

  void _follow() {
    _following?.cancel();
    final id = widget.id;
    _avatarId = _seen[id];
    _following = buildCommunitiesRepository()?.watch(id).listen((c) {
      if (c == null) return;
      _seen[id] = c.avatarId;
      if (mounted && c.avatarId != _avatarId) {
        setState(() => _avatarId = c.avatarId);
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommunityBadge(
    id: widget.id,
    name: widget.name,
    avatarId: _avatarId,
    size: widget.size,
  );
}

/// Community [id] as a small chip — its picture and name — for a profile.
/// Followed live, and nothing at all until it has loaded or if it is gone.
class CommunityChip extends StatefulWidget {
  const CommunityChip({super.key, required this.id, this.onTap});

  final String id;
  final VoidCallback? onTap;

  @override
  State<CommunityChip> createState() => _CommunityChipState();
}

class _CommunityChipState extends State<CommunityChip> {
  StreamSubscription<Community?>? _following;
  Community? _community;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(CommunityChip old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _follow();
  }

  void _follow() {
    _following?.cancel();
    _community = null;
    _following = buildCommunitiesRepository()?.watch(widget.id).listen((c) {
      if (mounted) setState(() => _community = c);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _community;
    if (c == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.elevated,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommunityBadge(
                id: c.id,
                name: c.name,
                avatarId: c.avatarId,
                size: 20,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
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

/// A room's picture: the globe for Global, the community's for its room.
class RoomPicture extends StatelessWidget {
  const RoomPicture({
    super.key,
    required this.room,
    required this.name,
    this.size = 48,
  });

  final String room;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final community = Community.ofRoom(room);
    return community == null
        ? RoomAvatar(size: size)
        : LiveCommunityBadge(id: community, name: name, size: size);
  }
}

/// What a room is called: Global in the reader's language, a community's
/// room by the community's name.
String roomTitle(Strings s, String room, String name) =>
    Community.ofRoom(room) == null ? s.globalChat : name;

/// An invitation to community [id], as a card in a conversation: its
/// picture, name and members, as they are now. Tapping it opens it.
class CommunityInviteCard extends StatefulWidget {
  const CommunityInviteCard({super.key, required this.id, this.onTap});

  final String id;
  final VoidCallback? onTap;

  @override
  State<CommunityInviteCard> createState() => _CommunityInviteCardState();
}

class _CommunityInviteCardState extends State<CommunityInviteCard> {
  StreamSubscription<Community?>? _following;
  Community? _community;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _following = buildCommunitiesRepository()
        ?.watch(widget.id)
        .listen(
          (c) {
            if (mounted) {
              setState(() {
                _community = c;
                _loaded = true;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loaded = true);
          },
        );
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = _community;
    return GestureDetector(
      onTap: c == null ? null : widget.onTap,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: c == null
            ? Text(
                _loaded ? s.communityUnavailable : '…',
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.communityInvite.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CommunityBadge(
                        id: c.id,
                        name: c.name,
                        avatarId: c.avatarId,
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              s.members(c.memberCount),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${s.seeCommunity} ›',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
