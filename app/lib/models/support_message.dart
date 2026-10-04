import 'package:cloud_firestore/cloud_firestore.dart';

/// Something written to the admins from the app, and their answer once
/// they give one (support/{id}; the answer is written by the worker).
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.text,
    this.sentAt,
    this.status = 'open',
    this.reply,
    this.repliedAt,
  });

  final String id;
  final String text;
  final DateTime? sentAt;

  /// 'open', 'answered' or 'closed'.
  final String status;
  final String? reply;
  final DateTime? repliedAt;

  bool get answered => reply != null && reply!.isNotEmpty;

  factory SupportMessage.fromJson(String id, Map<String, dynamic> json) {
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    final reply = json['reply'];
    return SupportMessage(
      id: id,
      text: json['text'] as String? ?? '',
      sentAt: time(json['createdAt']),
      status: json['status'] as String? ?? 'open',
      reply: reply is String && reply.isNotEmpty ? reply : null,
      repliedAt: time(json['repliedAt']),
    );
  }
}
