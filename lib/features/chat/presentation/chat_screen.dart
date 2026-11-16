import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({this.initialPeerId, super.key});

  final String? initialPeerId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver {
  final _roomSearch = TextEditingController();
  final _composer = TextEditingController();
  final _messageScroll = ScrollController();

  ChatRepository? _repository;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  String _ownerId = '';
  String? _error;
  List<ChatConversation> _rooms = const [];
  List<ChatMessage> _messages = const [];
  ChatConversation? _active;
  bool _started = false;
  bool _loading = true;
  bool _eligible = false;
  bool _connected = false;
  bool _historyLoading = false;
  bool _historyReady = false;
  bool _olderLoading = false;
  bool _hasOlder = false;
  bool _busy = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _foreground = true;
  int _roomRevision = 0;
  String? _retryId;
  String? _retryText;
  String? _retryRoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomSearch.addListener(_rebuild);
    _composer.addListener(_rebuild);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final session = AuthScope.read(context);
    final client = session.service.client;
    _ownerId = session.user?.id ?? '';
    if (client == null || _ownerId.isEmpty) {
      _loading = false;
      _error = 'Sign in to use private messages.';
      return;
    }
    _repository = ChatRepository(client);
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refreshLive());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    final channel = _channel;
    final repository = _repository;
    if (channel != null && repository != null) {
      unawaited(repository.unsubscribe(channel));
    }
    _roomSearch
      ..removeListener(_rebuild)
      ..dispose();
    _composer
      ..removeListener(_rebuild)
      ..dispose();
    _messageScroll.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    final repository = _repository;
    if (repository == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final allowed = await repository.eligible(_ownerId);
      if (!mounted) return;
      if (!allowed) {
        setState(() {
          _eligible = false;
          _loading = false;
          _rooms = const [];
          _messages = const [];
          _active = null;
        });
        return;
      }

      setState(() => _eligible = true);
      var rooms = await repository.inbox();
      if (!mounted) return;
      setState(() => _rooms = rooms);
      _subscribe();
      ChatConversation? directRoom;
      final peer = widget.initialPeerId?.trim() ?? '';
      if (peer.isNotEmpty && peer != _ownerId) {
        final roomId = await repository.openConversation(peer);
        rooms = await repository.inbox();
        directRoom = _findRoom(rooms, roomId);
        if (directRoom == null) {
          throw Exception('The conversation could not be opened.');
        }
      }
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
      if (directRoom != null) await _openRoom(directRoom);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _chatError(error);
        _loading = false;
      });
    }
  }

  void _subscribe() {
    if (_channel != null || _repository == null) return;
    _channel = _repository!.subscribe(
      userId: _ownerId,
      onChange: () => unawaited(_refreshLive()),
      onStatus: (connected) {
        if (mounted && _connected != connected) {
          setState(() => _connected = connected);
        }
      },
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refreshLive()),
    );
  }

  Future<void> _refreshLive() async {
    final repository = _repository;
    if (repository == null || !_eligible || !_foreground || !mounted) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final allowed = await repository.eligible(_ownerId);
        if (!mounted) return;
        if (!allowed) {
          setState(() {
            _eligible = false;
            _rooms = const [];
            _messages = const [];
            _active = null;
          });
          return;
        }
        final rooms = await repository.inbox();
        if (!mounted) return;
        final activeId = _active?.id;
        final refreshedActive = activeId == null
            ? null
            : _findRoom(rooms, activeId);
        setState(() {
          _rooms = rooms;
          if (activeId != null) _active = refreshedActive;
          _error = null;
        });
        if (refreshedActive != null && !_historyLoading && !_olderLoading) {
          await _loadNewer(refreshedActive);
          await _markRead(refreshedActive.id);
        }
      } while (_refreshAgain && mounted);
    } catch (error) {
      if (mounted) setState(() => _error = _chatError(error));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _openRoom(ChatConversation room) async {
    final repository = _repository;
    if (repository == null) return;
    final revision = ++_roomRevision;
    setState(() {
      _active = room;
      _messages = const [];
      _historyLoading = true;
      _historyReady = false;
      _olderLoading = false;
      _hasOlder = false;
      _error = null;
      _retryId = null;
      _retryText = null;
      _retryRoom = null;
      _composer.clear();
    });
    try {
      final messages = await repository.initialMessages(room.id);
      if (!mounted || revision != _roomRevision || _active?.id != room.id) {
        return;
      }
      setState(() {
        _messages = messages;
        _hasOlder = messages.length == 40;
        _historyReady = true;
        _historyLoading = false;
      });
      await _markRead(room.id);
      _scrollToBottom();
    } catch (error) {
      if (mounted && revision == _roomRevision) {
        setState(() {
          _error = _chatError(error);
          _historyLoading = false;
        });
      }
    }
  }

  void _closeRoom() {
    _roomRevision++;
    setState(() {
      _active = null;
      _messages = const [];
      _historyLoading = false;
      _historyReady = false;
      _olderLoading = false;
      _hasOlder = false;
      _retryId = null;
      _retryText = null;
      _retryRoom = null;
      _composer.clear();
    });
  }

  Future<void> _loadOlder() async {
    final repository = _repository;
    final room = _active;
    if (repository == null ||
        room == null ||
        _messages.isEmpty ||
        !_hasOlder ||
        _olderLoading) {
      return;
    }
    final revision = _roomRevision;
    final oldExtent = _messageScroll.hasClients
        ? _messageScroll.position.maxScrollExtent
        : 0.0;
    final oldOffset = _messageScroll.hasClients ? _messageScroll.offset : 0.0;
    setState(() {
      _olderLoading = true;
      _error = null;
    });
    try {
      final older = await repository.olderMessages(room.id, _messages.first);
      if (!mounted || revision != _roomRevision || _active?.id != room.id) {
        return;
      }
      setState(() {
        _messages = _mergeMessages([...older, ..._messages]);
        _hasOlder = older.length == 40;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_messageScroll.hasClients) return;
        final added = _messageScroll.position.maxScrollExtent - oldExtent;
        _messageScroll.jumpTo(
          (oldOffset + added)
              .clamp(0.0, _messageScroll.position.maxScrollExtent)
              .toDouble(),
        );
      });
    } catch (error) {
      if (mounted && revision == _roomRevision) {
        setState(() => _error = _chatError(error));
      }
    } finally {
      if (mounted && revision == _roomRevision) {
        setState(() => _olderLoading = false);
      }
    }
  }

  Future<void> _loadNewer(ChatConversation room) async {
    final repository = _repository;
    if (repository == null || !_historyReady) return;
    final revision = _roomRevision;
    final shouldFollow = !_messageScroll.hasClients ||
        _messageScroll.position.maxScrollExtent - _messageScroll.offset < 120;
    final newer = _messages.isEmpty
        ? await repository.initialMessages(room.id)
        : await repository.newerMessages(room.id, _messages.last);
    if (!mounted ||
        revision != _roomRevision ||
        _active?.id != room.id ||
        newer.isEmpty) {
      return;
    }
    setState(() {
      _messages = _mergeMessages([..._messages, ...newer]);
      if (_messages.length == newer.length) _hasOlder = newer.length == 40;
    });
    if (shouldFollow) _scrollToBottom();
  }

  Future<void> _retryCurrent() async {
    final room = _active;
    if (room != null && !_historyReady) {
      await _openRoom(room);
      return;
    }
    await _refreshLive();
  }

  Future<void> _markRead(String roomId) async {
    final repository = _repository;
    if (repository == null || !_foreground) return;
    await repository.markRead(roomId);
    if (!mounted) return;
    setState(() {
      _rooms = _rooms
          .map(
            (room) => room.id == roomId
                ? ChatConversation(
                    id: room.id,
                    peerId: room.peerId,
                    fullName: room.fullName,
                    username: room.username,
                    avatarUrl: room.avatarUrl,
                    lastMessage: room.lastMessage,
                    lastAt: room.lastAt,
                    unread: 0,
                    blockedByMe: room.blockedByMe,
                    canSend: room.canSend,
                  )
                : room,
          )
          .toList(growable: false);
    });
  }

  Future<void> _send() async {
    final repository = _repository;
    final room = _active;
    final text = _composer.text.trim();
    if (repository == null ||
        room == null ||
        !room.canSend ||
        text.isEmpty ||
        text.length > 2000 ||
        _busy) {
      return;
    }
    final messageId = _retryRoom == room.id && _retryText == text
        ? _retryId!
        : repository.newMessageId();
    _retryId = messageId;
    _retryText = text;
    _retryRoom = room.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.send(
        conversationId: room.id,
        messageId: messageId,
        text: text,
      );
      if (!mounted) return;
      if (_active?.id == room.id && _composer.text.trim() == text) {
        _composer.clear();
      }
      _retryId = null;
      _retryText = null;
      _retryRoom = null;
      await _refreshLive();
      _scrollToBottom();
    } catch (error) {
      if (mounted) setState(() => _error = _chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock() async {
    final repository = _repository;
    final room = _active;
    if (repository == null || room == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.setBlocked(room.peerId, !room.blockedByMe);
      await _refreshLive();
    } catch (error) {
      if (mounted) setState(() => _error = _chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    if (_busy || message.senderId == _ownerId || _repository == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain why this message should be reviewed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().length >= 3
                  ? () => Navigator.pop(dialogContext, value.text.trim())
                  : null,
              child: const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository!.reportMessage(message.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message report submitted for review.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newMessage() async {
    final repository = _repository;
    if (repository == null || _busy) return;
    final person = await showModalBottomSheet<ChatPerson>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (context) => _NewMessageSheet(repository: repository),
    );
    if (person == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roomId =
          person.conversationId ?? await repository.openConversation(person.id);
      final rooms = await repository.inbox();
      final room = _findRoom(rooms, roomId);
      if (room == null) throw Exception('The conversation could not be opened.');
      if (!mounted) return;
      setState(() => _rooms = rooms);
      await _openRoom(room);
    } catch (error) {
      if (mounted) setState(() => _error = _chatError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScroll.hasClients) return;
      _messageScroll.animateTo(
        _messageScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  List<ChatConversation> get _filteredRooms {
    final query = _roomSearch.text
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    if (query.isEmpty) return _rooms;
    return _rooms
        .where(
          (room) =>
              room.fullName.toLowerCase().contains(query) ||
              room.username.toLowerCase().contains(query) ||
              (room.lastMessage ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_eligible) {
      return _EligibilityGate(error: _error, retry: _initialize);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final showPageHeading = desktop || _active == null;
        return ColoredBox(
          color: AppColors.surface,
          child: SafeArea(
            child: Column(
              children: [
                if (showPageHeading) const _PageHeading(),
                if (_error != null)
                  _ErrorBanner(
                    message: _error!,
                    retry: _retryCurrent,
                    close: () => setState(() => _error = null),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          desktop ? 24 : 0,
                          desktop ? 8 : 0,
                          desktop ? 24 : 0,
                          desktop ? 22 : 0,
                        ),
                        child: Material(
                          color: AppColors.paper,
                          elevation: desktop ? 1 : 0,
                          borderRadius: BorderRadius.circular(desktop ? 18 : 0),
                          clipBehavior: Clip.antiAlias,
                          child: desktop
                              ? Row(
                                  children: [
                                    SizedBox(width: 370, child: _buildInbox()),
                                    const VerticalDivider(width: 1),
                                    Expanded(child: _buildConversation()),
                                  ],
                                )
                              : (_active == null
                                    ? _buildInbox()
                                    : _buildConversation()),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInbox() {
    final rooms = _filteredRooms;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your conversations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _connected
                                ? AppColors.success
                                : AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _connected ? 'Live' : 'Connecting…',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _newMessage,
                icon: const Icon(Icons.edit_square, size: 17),
                label: const Text('New'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _roomSearch,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search name, @username or message',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshLive,
            child: rooms.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: const [
                      SizedBox(height: 50),
                      _EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'No conversations yet',
                        message:
                            "Start a new message by searching a verified member's unique username.",
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 76,
                    ),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _RoomTile(
                        room: room,
                        selected: _active?.id == room.id,
                        onTap: () => _openRoom(room),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversation() {
    final room = _active;
    if (room == null) {
      return const _EmptyState(
        icon: Icons.mark_chat_unread_outlined,
        title: 'Your messages',
        message: 'Select a conversation to start chatting.',
      );
    }
    return Column(
      children: [
        _ConversationHeader(
          room: room,
          busy: _busy,
          close: _closeRoom,
          toggleBlock: _toggleBlock,
        ),
        const Divider(height: 1),
        Expanded(
          child: _historyLoading
              ? const Center(child: CircularProgressIndicator())
              : !_historyReady
              ? const _EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Messages unavailable',
                  message: 'Retry when your connection is available.',
                )
              : _messages.isEmpty
              ? const _EmptyState(
                  icon: Icons.waving_hand_outlined,
                  title: 'Say hello',
                  message:
                      'Keep conversations respectful. Share only information you are comfortable sharing.',
                )
              : ListView.builder(
                  controller: _messageScroll,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  itemCount: _messages.length + (_hasOlder ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_hasOlder && index == 0) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: _olderLoading ? null : _loadOlder,
                          icon: _olderLoading
                              ? const SizedBox.square(
                                  dimension: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.history_rounded),
                          label: Text(
                            _olderLoading
                                ? 'Loading…'
                                : 'Load earlier messages',
                          ),
                        ),
                      );
                    }
                    final message = _messages[index - (_hasOlder ? 1 : 0)];
                    return _MessageBubble(
                      message: message,
                      mine: message.senderId == _ownerId,
                      report: () => _reportMessage(message),
                    );
                  },
                ),
        ),
        if (!room.canSend)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            color: AppColors.surface,
            child: Text(
              room.blockedByMe
                  ? 'Unblock this member to send messages.'
                  : 'Messages cannot be sent to this member right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        _Composer(
          controller: _composer,
          enabled: room.canSend && !_busy,
          busy: _busy,
          send: _send,
        ),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 1280),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CITIZENNEWS',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Private conversations for active, verified members.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to news'),
          ),
        ],
      ),
    ),
  );
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final ChatConversation room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.red.withValues(alpha: .06) : Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _ChatAvatar(
              name: room.fullName,
              url: room.avatarUrl,
              radius: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '@${room.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.blockedByMe
                        ? 'Blocked'
                        : room.lastMessage ?? 'Start a conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: room.blockedByMe
                          ? AppColors.red
                          : AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _shortTime(room.lastAt),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                if (room.unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 21),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: Text(
                      room.unread > 99 ? '99+' : '${room.unread}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 21),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.room,
    required this.busy,
    required this.close,
    required this.toggleBlock,
  });

  final ChatConversation room;
  final bool busy;
  final VoidCallback close;
  final VoidCallback toggleBlock;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(7, 10, 10, 10),
    child: Row(
      children: [
        IconButton(
          onPressed: close,
          tooltip: 'Back to conversations',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        _ChatAvatar(name: room.fullName, url: room.avatarUrl, radius: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '@${room.username} · ${room.blockedByMe ? 'You blocked this member' : room.canSend ? 'Verified member' : 'Messaging unavailable'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: busy ? null : toggleBlock,
          child: Text(room.blockedByMe ? 'Unblock' : 'Block'),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.report,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback report;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 540),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
      decoration: BoxDecoration(
        color: mine ? AppColors.red : AppColors.surface,
        border: mine ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.body,
            style: TextStyle(color: mine ? Colors.white : AppColors.ink),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _messageTime(message.createdAt),
                style: TextStyle(
                  color: mine ? Colors.white70 : AppColors.muted,
                  fontSize: 10,
                ),
              ),
              if (!mine) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: report,
                  child: const Text(
                    'Report',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.send,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final VoidCallback send;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Write a message…',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled && controller.text.trim().isNotEmpty
                ? send
                : null,
            tooltip: busy ? 'Sending message' : 'Send message',
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    ),
  );
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet({required this.repository});

  final ChatRepository repository;

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false;
  String? _error;
  List<ChatPerson> _people = const [];

  @override
  void dispose() {
    _revision++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final query = value.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (query.length < 2) {
      _revision++;
      setState(() {
        _loading = false;
        _error = null;
        _people = const [];
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await widget.repository.searchPeople(query);
      if (!mounted || revision != _revision) return;
      setState(() => _people = people);
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = _chatError(error));
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final queryLength = _search.text
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .length;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'New message',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Find an active, verified member by unique username.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              autofocus: true,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              onChanged: _changed,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: '@username',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (queryLength < 2)
              const Expanded(
                child: Center(
                  child: Text(
                    'Enter at least two username characters.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else if (_people.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No verified member found with this username.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _people.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final person = _people[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: _ChatAvatar(
                        name: person.fullName,
                        url: person.avatarUrl,
                        radius: 22,
                      ),
                      title: Text(person.fullName),
                      subtitle: Text(
                        '@${person.username}${person.followed ? ' · Following' : ''}',
                      ),
                      trailing: Text(
                        person.conversationId == null ? 'Message' : 'Open',
                        style: const TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, person),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.name,
    required this.url,
    required this.radius,
  });

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: AppColors.ink,
      child: Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * .72,
        ),
      ),
    );
    if (url == null) {
      return ClipOval(child: fallback);
    }
    return ClipOval(
      child: Image.network(
        url!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _EligibilityGate extends StatelessWidget {
  const _EligibilityGate({required this.error, required this.retry});

  final String? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.red,
                    size: 54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verified members only',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Both people need an approved identity verification and an active account to chat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.red),
                    ),
                    TextButton(onPressed: retry, child: const Text('Retry')),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => context.go('/verification'),
                    child: const Text('View verification'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.retry,
    required this.close,
  });

  final String message;
  final Future<void> Function() retry;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.red.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.red),
        const SizedBox(width: 9),
        Expanded(child: Text(message)),
        TextButton(onPressed: retry, child: const Text('Retry')),
        IconButton(
          onPressed: close,
          icon: const Icon(Icons.close_rounded, size: 19),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 47, color: AppColors.red),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

ChatConversation? _findRoom(List<ChatConversation> rooms, String id) {
  for (final room in rooms) {
    if (room.id == id) return room;
  }
  return null;
}

List<ChatMessage> _mergeMessages(Iterable<ChatMessage> values) {
  final byId = <String, ChatMessage>{};
  for (final message in values) {
    byId[message.id] = message;
  }
  final result = byId.values.toList();
  result.sort((a, b) {
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  });
  return result;
}

String _chatError(Object error) {
  final raw = error is PostgrestException ? error.message : error.toString();
  if (RegExp('active, verified|two active, verified', caseSensitive: false)
      .hasMatch(raw)) {
    return 'Chat is available to active members with approved verification.';
  }
  if (RegExp('messaging is unavailable', caseSensitive: false).hasMatch(raw)) {
    return 'Messaging is unavailable for this conversation.';
  }
  if (RegExp('too many messages', caseSensitive: false).hasMatch(raw)) {
    return 'Too many messages. Please wait a minute and try again.';
  }
  if (RegExp('report reason', caseSensitive: false).hasMatch(raw)) {
    return 'Enter a report reason between 3 and 500 characters.';
  }
  if (RegExp('conversation could not be opened', caseSensitive: false)
      .hasMatch(raw)) {
    return 'The conversation could not be opened.';
  }
  return AppError.message(error);
}

String _shortTime(DateTime value) {
  final now = DateTime.now();
  if (now.year == value.year &&
      now.month == value.month &&
      now.day == value.day) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
  if (now.difference(value).inDays < 7) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][
        value.weekday - 1];
  }
  return '${value.day}/${value.month}';
}

String _messageTime(DateTime value) {
  final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day}/${value.month} · $hour:'
      '${value.minute.toString().padLeft(2, '0')} $period';
}
