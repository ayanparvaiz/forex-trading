/// Where two traders stand with each other.
enum ConnectionStatus {
  /// No request either way.
  none,

  /// You asked, they have not answered.
  pendingOutgoing,

  /// They asked, it is your call.
  pendingIncoming,

  /// Both agreed.
  connected;

  bool get isPending =>
      this == pendingOutgoing || this == pendingIncoming;
}

/// A connection request, in whatever state it has reached.
///
/// Stored once, from the requester's side, rather than twice. Two rows for one
/// relationship is two rows to keep in step, and they will drift.
class Connection {
  const Connection({
    required this.from,
    required this.to,
    required this.accepted,
    required this.requestedAt,
    this.respondedAt,
  });

  /// Username of whoever sent the request.
  final String from;

  /// Username of whoever received it.
  final String to;

  final bool accepted;
  final DateTime requestedAt;
  final DateTime? respondedAt;

  /// True when [username] is either side of this connection.
  bool involves(String username) => from == username || to == username;

  /// The other person, seen from [username].
  String otherThan(String username) => from == username ? to : from;

  /// How this looks to [username].
  ConnectionStatus statusFor(String username) {
    if (accepted) return ConnectionStatus.connected;
    return from == username
        ? ConnectionStatus.pendingOutgoing
        : ConnectionStatus.pendingIncoming;
  }

  Connection accept() => Connection(
        from: from,
        to: to,
        accepted: true,
        requestedAt: requestedAt,
        respondedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'accepted': accepted,
        'requestedAt': requestedAt.toIso8601String(),
        if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
      };

  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
        from: json['from'] as String,
        to: json['to'] as String,
        accepted: json['accepted'] as bool? ?? false,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        respondedAt: json['respondedAt'] == null
            ? null
            : DateTime.parse(json['respondedAt'] as String),
      );
}

/// A record that someone opened someone else's profile.
class ProfileView {
  const ProfileView({
    required this.viewer,
    required this.profileId,
    required this.viewedAt,
  });

  /// Username of whoever looked.
  final String viewer;

  /// Username of the profile that was looked at.
  final String profileId;

  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {
        'viewer': viewer,
        'profileId': profileId,
        'viewedAt': viewedAt.toIso8601String(),
      };

  factory ProfileView.fromJson(Map<String, dynamic> json) => ProfileView(
        viewer: json['viewer'] as String,
        profileId: json['profileId'] as String,
        viewedAt: DateTime.parse(json['viewedAt'] as String),
      );
}
