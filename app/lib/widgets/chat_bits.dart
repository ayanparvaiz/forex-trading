import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../theme/app_theme.dart';
import 'avatar_image.dart';

/// WhatsApp's read-receipt blue: the one colour here that is not from the
/// app's palette, because it is the colour people already read as "seen".
const readTickColor = Color(0xFF53BDEB);

/// An avatar with a green dot when its owner is active now.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.avatarId,
    required this.activeNow,
    this.size = 48,
  });

  final int avatarId;
  final bool activeNow;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.28;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarImage(avatarId, size: size),
          if (activeNow)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: AppColors.profit,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tick on a message you sent.
class MessageTicks extends StatelessWidget {
  const MessageTicks({super.key, required this.status, this.size = 15});

  final MessageStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      MessageStatus.pending => (Icons.schedule, AppColors.textMuted, 'Sending'),
      MessageStatus.sent => (Icons.done, AppColors.textMuted, 'Sent'),
      MessageStatus.delivered => (
        Icons.done_all,
        AppColors.textMuted,
        'Delivered',
      ),
      MessageStatus.read => (Icons.done_all, readTickColor, 'Read'),
    };
    return Semantics(
      label: label,
      child: Icon(
        icon,
        size: status == MessageStatus.pending ? size - 3 : size,
        color: color,
      ),
    );
  }
}
