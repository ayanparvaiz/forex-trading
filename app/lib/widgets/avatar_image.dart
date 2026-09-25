import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/avatars.dart';

/// A profile avatar, drawn from its stored number.
///
/// Takes the id rather than an [Avatar] so every call site passes what the
/// database actually holds, and the lookup — including the fallback for an id
/// a newer build introduced — happens in one place.
class AvatarImage extends StatelessWidget {
  const AvatarImage(this.id, {super.key, this.size = 40});

  final int? id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatar = Avatars.byId(id);
    return SvgPicture.asset(
      avatar.asset,
      width: size,
      height: size,
      semanticsLabel: avatar.en,
      // The artwork is already a circle; a fixed box keeps rows from jumping
      // while the file is parsed on first use.
      placeholderBuilder: (_) => SizedBox.square(dimension: size),
    );
  }
}
