import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

class LocalizationController extends ChangeNotifier {
  static const preferenceKey = 'citizennews-language';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _language = AppLanguage.fromCode(preferences.getString(preferenceKey));
      notifyListeners();
    } catch (_) {
      _language = AppLanguage.english;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(preferenceKey, language.code);
    } catch (_) {
      // The selected language still applies for the current app session.
    }
  }
}
