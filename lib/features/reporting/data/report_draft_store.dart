import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReportDraftStore {
  const ReportDraftStore();

  String _key(String owner, String routeKey) =>
      'citizennews.report.draft.$owner.$routeKey';

  Future<Map<String, dynamic>?> read(String owner, String routeKey) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key(owner, routeKey));
    if (value == null || value.isEmpty) return null;
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<void> write(
    String owner,
    String routeKey,
    Map<String, dynamic> value,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(owner, routeKey), jsonEncode(value));
  }

  Future<void> remove(String owner, String routeKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(owner, routeKey));
  }
}
