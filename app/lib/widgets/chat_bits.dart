import 'dart:math' as math;

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

/// Three dots rising in turn inside an incoming bubble: the other person is
/// typing. Shown at the bottom of the conversation, where their message is
/// about to appear.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.bubbleTheirs,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.circular(3),
          ),
        ),
        child: AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                _dot(i),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Each dot runs the same rise-and-fall a little after the one before it,
  /// then rests — so the three read as one wave, not a flicker.
  Widget _dot(int i) {
    final t = (_wave.value - i * 0.18) % 1.0;
    final lift = t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0.0;
    return Transform.translate(
      offset: Offset(0, -4 * lift),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.textMuted, AppColors.textSecondary, lift),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
