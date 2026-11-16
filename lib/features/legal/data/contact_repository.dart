import 'package:supabase_flutter/supabase_flutter.dart';

class ContactRepository {
  const ContactRepository(this.client);

  final SupabaseClient client;

  Future<void> send({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await client.rpc<dynamic>(
      'send_contact',
      params: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'subject': subject.trim(),
        'message': message.trim(),
      },
    );
  }
}
