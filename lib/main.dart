import 'package:flutter/material.dart';

import 'app/citizen_news_app.dart';
import 'core/errors/app_error.dart';
import 'core/localization/localization_controller.dart';
import 'features/auth/application/auth_session_controller.dart';
import 'features/auth/data/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late AuthService authService;
  String? startupError;
  try {
    authService = await AuthService.initialize();
  } catch (error) {
    authService = AuthService.unconfigured();
    startupError = AppError.message(error);
  }
  final session = AuthSessionController(
    authService,
    startupError: startupError,
  );
  final localization = LocalizationController();
  await Future.wait([session.initialize(), localization.initialize()]);
  runApp(CitizenNewsApp(session: session, localization: localization));
}
