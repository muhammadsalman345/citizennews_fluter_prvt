class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.peerId,
    required this.fullName,
    required this.username,
    required this.lastAt,
    required this.unread,
    required this.blockedByMe,
    required this.canSend,
    this.avatarUrl,
    this.lastMessage,
  });

  final String id;
  final String peerId;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime lastAt;
  final int unread;
  final bool blockedByMe;
  final bool canSend;

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id']?.toString() ?? '',
        peerId: json['peer_id']?.toString() ?? '',
        fullName: _nonEmpty(json['full_name'], 'Member'),
        username: _nonEmpty(json['username'], 'member'),
        avatarUrl: _nullableText(json['avatar_url']),
        lastMessage: _nullableText(json['last_message']),
        lastAt: _date(json['last_at']),
        unread: _integer(json['unread']),
        blockedByMe: json['blocked_by_me'] == true,
        canSend: json['can_send'] == true,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    conversationId: json['conversation_id']?.toString() ?? '',
    senderId: json['sender_id']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt: _date(json['created_at']),
  );
}

class ChatPerson {
  const ChatPerson({
    required this.id,
    required this.fullName,
    required this.username,
    required this.followed,
    this.avatarUrl,
    this.conversationId,
  });

  final String id;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final bool followed;
  final String? conversationId;

  factory ChatPerson.fromJson(Map<String, dynamic> json) => ChatPerson(
    id: json['id']?.toString() ?? '',
    fullName: _nonEmpty(json['full_name'], 'Member'),
    username: _nonEmpty(json['username'], 'member'),
    avatarUrl: _nullableText(json['avatar_url']),
    followed: json['followed'] == true,
    conversationId: _nullableText(json['conversation_id']),
  );
}

String _nonEmpty(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);

int _integer(dynamic value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};
