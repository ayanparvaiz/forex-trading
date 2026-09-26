import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/communities_repository.dart';
import '../data/community_avatars.dart';
import '../i18n/strings.dart';
import '../models/community.dart';
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
