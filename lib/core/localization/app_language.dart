import 'package:flutter/widgets.dart';

enum AppLanguage {
  english(code: 'en', nativeName: 'English'),
  urdu(code: 'ur', nativeName: 'اردو', rtl: true),
  arabic(code: 'ar', nativeName: 'العربية', rtl: true),
  spanish(code: 'es', nativeName: 'Español'),
  french(code: 'fr', nativeName: 'Français'),
  german(code: 'de', nativeName: 'Deutsch');

  const AppLanguage({
    required this.code,
    required this.nativeName,
    this.rtl = false,
  });

  final String code;
  final String nativeName;
  final bool rtl;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => english,
  );
}

const supportedAppLocales = <Locale>[
  Locale('en'),
  Locale('ur'),
  Locale('ar'),
  Locale('es'),
  Locale('fr'),
  Locale('de'),
];
