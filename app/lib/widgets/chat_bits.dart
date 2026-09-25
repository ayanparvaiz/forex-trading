import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// The colour a quoted message is marked with: one for you, one for the
/// other person, so a reply shows at a glance whose words it answers.
Color quoteAccent({required bool mine}) =>
    mine ? AppColors.profit : AppColors.discipline;

/// A quoted message: a coloured edge, whose it was, and a line or two of it.
/// Inside a reply bubble, and above the message box while writing one.
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.name,
    required this.text,
    required this.accent,
    this.italic = false,
    this.maxLines = 2,
    this.onTap,
  });

  final String name;
  final String text;
  final Color accent;

  /// For a message that is gone or not yet loaded, rather than its words.
  final bool italic;
  final int maxLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border(left: BorderSide(color: accent, width: 3.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipe a message to the right to reply to it, as in WhatsApp.
///
/// The message follows the finger a short way and a reply arrow fades in
/// behind it; past the trigger point the phone ticks once, and letting go
/// there replies. Anywhere short of it, the message just springs back.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.enabled,
    required this.onReply,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onReply;
  final Widget child;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _trigger = 56.0;
  static const _max = 76.0;

  // Made up front, not lazily: a lazy one would first be made in dispose()
  // when swiping was never on, and a ticker cannot be made then.
  late final AnimationController _back;

  @override
  void initState() {
    super.initState();
    _back = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_springBack);
  }

  double _dx = 0;
  double _releasedAt = 0;
  bool _armed = false;

  void _springBack() {
    setState(
      () => _dx = _releasedAt * (1 - Curves.easeOut.transform(_back.value)),
    );
  }

  void _update(DragUpdateDetails d) {
    _back.stop();
    setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, _max));
    if (!_armed && _dx >= _trigger) {
      _armed = true;
      HapticFeedback.lightImpact();
    } else if (_armed && _dx < _trigger) {
      _armed = false;
    }
  }

  void _release({required bool reply}) {
    if (reply && _armed) widget.onReply();
    _armed = false;
    _releasedAt = _dx;
    _back.forward(from: 0);
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: (_) => _release(reply: true),
      onHorizontalDragCancel: () => _release(reply: false),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dx > 0)
            Positioned(
              left: 4,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      size: 19,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// The Global room's picture: a globe, since it is everyone.
class RoomAvatar extends StatelessWidget {
  const RoomAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDim],
        ),
      ),
      child: Icon(Icons.public_rounded, size: size * 0.56, color: Colors.white),
    );
  }
}
