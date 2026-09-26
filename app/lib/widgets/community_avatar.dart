import 'package:flutter/material.dart';

import 'conversation_view.dart';

/// A community's picture: its initial on its own colour.
///
/// Rounded square rather than round, so a community never looks like a
/// person in a list of people. The colour comes from the id, so it stays the
/// same wherever the community shows up, and two with similar names still
/// look different.
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    required this.id,
    required this.name,
    this.size = 48,
  });

  final String id;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = senderColor(id);
    final initial = name.trim().isEmpty
        ? '#'
        : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
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
