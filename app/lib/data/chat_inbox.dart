import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/chat.dart';
import 'chat_repository.dart';
import 'room_repository.dart';
import 'safety_repository.dart';

/// A message that arrived in a conversation you are not looking at.
class ChatArrival {
  const ChatArrival({required this.thread, required this.partner});

  final ChatThread thread;
  final ChatPartner? partner;
}

/// Everything about your conversations that has to stay alive while the app
/// is open, whichever tab you are on.
///
/// One listener on your conversation list feeds the inbox, the unread badge
/// on the tab bar and the banners for new messages. The same object keeps
/// your presence fresh and tells senders their messages reached you.
///
/// Delivery is honest about when it happens. It is marked when this listener
/// sees the message, which is when your app is open — so without push
/// notifications, a message to a closed app shows one grey tick until its
/// recipient opens the app, which is what the tick means.
class ChatInbox extends ChangeNotifier with WidgetsBindingObserver {
  ChatInbox({
    required this.repository,
    required this.uid,
    this.safety,
    this.rooms,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _blocksSub = safety?.watchBlocks(uid).listen((blocked) {
      _blocked = {for (final b in blocked) b.uid: b};
      notifyListeners();
    }, onError: (Object e) => debugPrint('blocks stream failed: $e'));
    _prefsSub = repository.watchPrefs(uid).listen((prefs) {
      _prefs = prefs;
      notifyListeners();
    }, onError: (Object e) => debugPrint('chat prefs stream failed: $e'));
    _threadsSub = repository
        .watchThreads(uid)
        .listen(_onThreads, onError: _onError);
    _watchGlobal();
    _startHeartbeat();
    // Connections made before messaging existed get their conversation now,
    // so everyone you know is already in the list.
    unawaited(
      repository
          .ensureChatsForConnections(uid)
          .catchError((Object e) => debugPrint('chat backfill failed: $e')),
    );
  }

  final ChatRepository repository;
  final String uid;

  /// Blocks, kept here because this is the one object alive for the whole
  /// signed-in session and every screen can reach — the feed, the chat and
  /// profiles all need to know who you have blocked.
  final SafetyRepository? safety;

  /// The Global room, which everyone sees at the top of the inbox.
  final RoomRepository? rooms;

  StreamSubscription<List<BlockedAccount>>? _blocksSub;
  Map<String, BlockedAccount> _blocked = const {};

  List<BlockedAccount> get blocked => _blocked.values.toList();
  bool isBlocked(String otherUid) => _blocked.containsKey(otherUid);

  /// Usernames you have blocked — the feed identifies authors by username.
  Set<String> get blockedUsernames => {
    for (final b in _blocked.values) b.username,
  };

  List<ChatThread> _threads = const [];

  /// Your conversations, less the ones you have deleted and nobody has
  /// written in since.
  List<ChatThread> get threads => [
    for (final t in _threads)
      if (prefsFor(t.id).listsThread(t)) t,
  ];

  StreamSubscription<Map<String, ChatPrefs>>? _prefsSub;
  Map<String, ChatPrefs> _prefs = const {};

  /// What you have deleted for yourself in [chatId].
  ChatPrefs prefsFor(String chatId) => _prefs[chatId] ?? ChatPrefs.none;

  bool _loaded = false;
  bool get loaded => _loaded;

  Object? _error;
  Object? get error => _error;

  final Map<String, ChatPartner> _partners = {};
  ChatPartner? partner(String otherUid) => _partners[otherUid];

  Map<String, DateTime> _presence = const {};
  DateTime? lastActive(String otherUid) => _presence[otherUid];

  // --- The Global room -------------------------------------------------------

  StreamSubscription<RoomInfo?>? _roomSub;
  StreamSubscription<RoomMembership?>? _memberSub;

  RoomInfo? _global;
  RoomInfo? get global => _global;

  RoomMembership? _membership;
  RoomMembership? get globalMembership => _membership;

  /// Joined: the room counts unread for you and brings banners.
  bool get joinedGlobal => _membership != null;

  /// Whether the membership has been heard from yet — until then, the row
  /// cannot say "Join now" without flickering for people who have joined.
  bool _membershipKnown = false;
  bool get globalKnown => _global != null && _membershipKnown;

  int _globalUnread = 0;

  /// Messages since you last looked; nothing for someone who has not joined.
  int get globalUnread => joinedGlobal ? _globalUnread : 0;

  void _watchGlobal() {
    final rooms = this.rooms;
    if (rooms == null) return;
    _roomSub = rooms.watchRoom(RoomRepository.globalId).listen((room) {
      _global = room;
      _refreshGlobalUnread();
      notifyListeners();
    }, onError: (Object e) => debugPrint('global room stream failed: $e'));
    _memberSub = rooms.watchMembership(RoomRepository.globalId, uid).listen((
      m,
    ) {
      _membership = m;
      _membershipKnown = true;
      _refreshGlobalUnread();
      notifyListeners();
    }, onError: (Object e) => debugPrint('membership stream failed: $e'));
  }

  /// Bumped per question, so a slow answer never overwrites a newer one.
  int _unreadAsked = 0;

  /// Counts what is new since your mark. One aggregate read, and only when
  /// something has been said since — never for an up-to-date member.
  Future<void> _refreshGlobalUnread() async {
    final rooms = this.rooms;
    final m = _membership;
    final room = _global;
    final ask = ++_unreadAsked;
    if (rooms == null || m == null || room == null || !m.behind(room)) {
      if (_globalUnread != 0) {
        _globalUnread = 0;
        notifyListeners();
      }
      return;
    }
    try {
      final n = await rooms.unreadSince(room.id, m.readAt);
      if (ask != _unreadAsked) return;
      _globalUnread = n;
      notifyListeners();
    } catch (e) {
      debugPrint('global unread failed: $e');
    }
  }

  /// Conversations with something unread — the number on the tab.
  ///
  /// Muted ones are left out, as in WhatsApp: muting is asking not to be
  /// nudged, and a number on the tab is a nudge.
  int get unreadChats {
    final now = DateTime.now();
    final chats = threads
        .where((t) => t.unreadFor(uid) > 0 && !prefsFor(t.id).mutedAt(now))
        .length;
    final global =
        globalUnread > 0 && !prefsFor(RoomRepository.globalId).mutedAt(now);
    return chats + (global ? 1 : 0);
  }

  /// The conversation currently on screen, if any. Its messages get no
  /// banner, because you are already reading them.
  String? openChatId;

  final _arrivals = StreamController<ChatArrival>.broadcast();
  Stream<ChatArrival> get arrivals => _arrivals.stream;

  StreamSubscription<List<ChatThread>>? _threadsSub;
  StreamSubscription<Map<String, DateTime>>? _presenceSub;
  List<String> _presenceFor = const [];

  /// Newest message id per conversation, from the previous snapshot. Null
  /// until the first one, so opening the app does not announce old news.
  Map<String, String?>? _lastIds;

  bool _foreground = true;
  Timer? _heartbeat;

  /// Set while the account is being deleted: a beat in the middle would
  /// write back the presence the worker has just erased.
  bool _presencePaused = false;

  /// Delivery marks asked for and not yet reflected back, so a slow
  /// acknowledgement does not trigger the same write twice.
  final Map<String, DateTime> _deliveryRequested = {};
  Timer? _deliveryTimer;

  void _onThreads(List<ChatThread> threads) {
    final arrivals = newArrivals(
      before: _lastIds,
      now: threads,
      me: uid,
      openChatId: openChatId,
    );
    _lastIds = {for (final t in threads) t.id: t.lastMessage?.id};
    _threads = threads;
    _loaded = true;
    _error = null;

    _loadMissingPartners();
    _watchPresenceOfVisible();
    _scheduleDelivery();

    if (_foreground) {
      for (final t in arrivals) {
        // Nobody you have blocked gets a banner. The rules already stop them
        // sending anything new; this covers a message that crossed with the
        // block.
        if (isBlocked(t.otherUid(uid))) continue;
        // Nor does a conversation you have muted.
        if (prefsFor(t.id).mutedAt(DateTime.now())) continue;
        _arrivals.add(
          ChatArrival(thread: t, partner: _partners[t.otherUid(uid)]),
        );
      }
    }
    notifyListeners();
  }

  void _onError(Object error) {
    debugPrint('inbox stream failed: $error');
    _error = error;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadMissingPartners() async {
    final missing = [
      for (final t in _threads)
        if (!_partners.containsKey(t.otherUid(uid))) t.otherUid(uid),
    ];
    if (missing.isEmpty) return;
    try {
      _partners.addAll(await repository.partners(missing));
      notifyListeners();
    } catch (e) {
      debugPrint('chat partners failed: $e');
    }
  }

  /// Presence for the first thirty conversations — the ones a phone screen
  /// can show — resubscribed only when that set actually changes.
  void _watchPresenceOfVisible() {
    final wanted = [for (final t in _threads.take(30)) t.otherUid(uid)]..sort();
    if (_sameList(wanted, _presenceFor)) return;
    _presenceFor = wanted;
    _presenceSub?.cancel();
    _presenceSub = repository.watchPresence(wanted).listen((p) {
      _presence = p;
      notifyListeners();
    }, onError: (Object e) => debugPrint('presence failed: $e'));
  }

  void _scheduleDelivery() {
    _deliveryTimer?.cancel();
    _deliveryTimer = Timer(const Duration(milliseconds: 800), _markDelivered);
  }

  void _markDelivered() {
    if (!_foreground) return;
    final due = <String>[];
    for (final t in _threads) {
      final last = t.lastMessage;
      if (last == null || last.senderUid == uid) continue;
      final mark = t.deliveredAt[uid];
      if (mark != null && !t.updatedAt.isAfter(mark)) continue;
      if (_deliveryRequested[t.id] == t.updatedAt) continue;
      _deliveryRequested[t.id] = t.updatedAt;
      due.add(t.id);
    }
    if (due.isEmpty) return;
    repository.markDelivered(due, uid).catchError((Object e) {
      debugPrint('mark delivered failed: $e');
      due.forEach(_deliveryRequested.remove);
    });
  }

  // --- Presence ---------------------------------------------------------------

  /// A beat a minute while the app is in front; one more on the way out, so
  /// "last active" is when you actually left rather than up to a minute early.
  void _startHeartbeat() {
    if (_presencePaused) return;
    _beat();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) => _beat());
  }

  void _beat() {
    if (_presencePaused) return;
    repository.beat(uid).catchError((Object e) {
      debugPrint('presence beat failed: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _startHeartbeat();
      _scheduleDelivery();
    } else {
      _heartbeat?.cancel();
      _beat();
    }
  }

  bool get isForeground => _foreground;

  /// Stops "active now" being written, until [resumePresence].
  void pausePresence() {
    _presencePaused = true;
    _heartbeat?.cancel();
  }

  void resumePresence() {
    if (!_presencePaused) return;
    _presencePaused = false;
    if (_foreground) _startHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _threadsSub?.cancel();
    _roomSub?.cancel();
    _memberSub?.cancel();
    _prefsSub?.cancel();
    _blocksSub?.cancel();
    _presenceSub?.cancel();
    _heartbeat?.cancel();
    _deliveryTimer?.cancel();
    _arrivals.close();
    super.dispose();
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Puts the [ChatInbox] in the tree. Null when there is no messaging server.
class InboxScope extends InheritedNotifier<ChatInbox> {
  const InboxScope({super.key, required ChatInbox? inbox, required super.child})
    : super(notifier: inbox);

  /// Rebuilds the caller when the inbox changes.
  static ChatInbox? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InboxScope>()?.notifier;

  /// Reads the inbox without subscribing to its changes.
  static ChatInbox? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<InboxScope>()?.notifier;
}
