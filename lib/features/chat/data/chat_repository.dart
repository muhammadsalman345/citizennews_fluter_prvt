import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_models.dart';

class ChatRepository {
  ChatRepository(this.client);

  final SupabaseClient client;
  final Random _random = Random.secure();

  Future<bool> eligible(String userId) async {
    final value = await client.rpc<dynamic>(
      'chat_eligible',
      params: {'person': userId},
    );
    return value == true;
  }

  Future<List<ChatConversation>> inbox() async {
    final value = await client.rpc<dynamic>('chat_inbox');
    return _rows(value).map(ChatConversation.fromJson).toList(growable: false);
  }

  Future<List<ChatPerson>> searchPeople(String username) async {
    final query = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (query.length < 2) return const [];
    final value = await client.rpc<dynamic>(
      'chat_people_search',
      params: {'username_query': query},
    );
    return _rows(value).map(ChatPerson.fromJson).toList(growable: false);
  }

  Future<String> openConversation(String peerId) async {
    final value = await client.rpc<dynamic>(
      'chat_open',
      params: {'peer': peerId},
    );
    return value.toString();
  }

  Future<List<ChatMessage>> initialMessages(
    String conversationId, {
    int limit = 40,
  }) async {
    final value = await client
        .from('chat_messages')
        .select('id,conversation_id,sender_id,body,created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return _rows(value)
        .map(ChatMessage.fromJson)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<List<ChatMessage>> olderMessages(
    String conversationId,
    ChatMessage before, {
    int limit = 40,
  }) async {
    final timestamp = before.createdAt.toUtc().toIso8601String();
    final value = await client
        .from('chat_messages')
        .select('id,conversation_id,sender_id,body,created_at')
        .eq('conversation_id', conversationId)
        .or(
          'created_at.lt.$timestamp,'
          'and(created_at.eq.$timestamp,id.lt.${before.id})',
        )
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return _rows(value)
        .map(ChatMessage.fromJson)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<List<ChatMessage>> newerMessages(
    String conversationId,
    ChatMessage after,
  ) async {
    final timestamp = after.createdAt.toUtc().toIso8601String();
    final value = await client
        .from('chat_messages')
        .select('id,conversation_id,sender_id,body,created_at')
        .eq('conversation_id', conversationId)
        .or(
          'created_at.gt.$timestamp,'
          'and(created_at.eq.$timestamp,id.gt.${after.id})',
        )
        .order('created_at')
        .order('id')
        .limit(1000);
    return _rows(value).map(ChatMessage.fromJson).toList(growable: false);
  }

  Future<void> markRead(String conversationId) => client.rpc<void>(
    'chat_read',
    params: {'room': conversationId},
  );

  Future<void> send({
    required String conversationId,
    required String messageId,
    required String text,
  }) async {
    await client.rpc<dynamic>(
      'chat_send',
      params: {
        'room': conversationId,
        'message_id': messageId,
        'message_text': text.trim(),
      },
    );
  }

  Future<void> setBlocked(String peerId, bool blocked) => client.rpc<void>(
    'chat_block',
    params: {'peer': peerId, 'blocked': blocked},
  );

  Future<void> reportMessage(String messageId, String reason) async {
    await client.rpc<dynamic>(
      'report_chat_message',
      params: {'message_id': messageId, 'reason': reason.trim()},
    );
  }

  String newMessageId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  RealtimeChannel subscribe({
    required String userId,
    required void Function() onChange,
    required void Function(bool connected) onStatus,
  }) {
    final channel = client
        .channel('flutter-chat-$userId-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_conversations',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_blocks',
          callback: (_) => onChange(),
        );
    channel.subscribe((status, _) {
      onStatus(status == RealtimeSubscribeStatus.subscribed);
      if (status == RealtimeSubscribeStatus.subscribed) onChange();
    });
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List? ?? const [])
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
