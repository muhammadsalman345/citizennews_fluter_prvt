import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../core/theme/app_theme.dart';
import '../core/ads/ads_controller.dart';
import '../core/ads/ads_scope.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/localization_controller.dart';
import '../core/localization/localization_scope.dart';
import '../core/network/network_controller.dart';
import '../core/network/network_scope.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/auth/presentation/auth_scope.dart';
import '../features/location/application/location_controller.dart';
import '../features/location/data/location_repository.dart';
import '../features/location/presentation/location_scope.dart';
import 'routing/app_router.dart';

class CitizenNewsApp extends StatelessWidget {
  factory CitizenNewsApp({
    AuthSessionController? session,
    LocalizationController? localization,
    AdsController? ads,
    NetworkController? network,
    Key? key,
  }) {
    final controller = session ?? AuthSessionController.unconfigured();
    final languageController = localization ?? LocalizationController();
    final adsController = ads ?? AdsController();
    final networkController = network ?? NetworkController();
    if (localization == null) unawaited(languageController.initialize());
    if (ads == null) unawaited(adsController.initialize());
    if (network == null) unawaited(networkController.initialize());
    final location = LocationController(
      LocationRepository(controller.service.client),
    );
    unawaited(location.initialize());
    return CitizenNewsApp._(
      session: controller,
      location: location,
      localization: languageController,
      ads: adsController,
      network: networkController,
      router: createAppRouter(controller),
      key: key,
    );
  }

  const CitizenNewsApp._({
    required this.session,
    required this.location,
    required this.localization,
    required this.ads,
    required this.network,
    required this.router,
    super.key,
  });

  final AuthSessionController session;
  final LocationController location;
  final LocalizationController localization;
  final AdsController ads;
  final NetworkController network;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return LocalizationScope(
      controller: localization,
      child: NetworkScope(
        controller: network,
        child: AdsScope(
          controller: ads,
          child: _AppView(
            session: session,
            location: location,
            router: router,
          ),
        ),
      ),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView({
    required this.session,
    required this.location,
    required this.router,
  });

  final AuthSessionController session;
  final LocationController location;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final language = LocalizationScope.watch(context).language;
    return AuthScope(
      controller: session,
      child: LocationScope(
        controller: location,
        child: MaterialApp.router(
          onGenerateTitle: (context) => 'CitizenNews',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: language.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...PhoneFieldLocalization.delegates,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: supportedAppLocales,
          localeListResolutionCallback: (locales, supported) {
            return language.locale;
          },
          routerConfig: router,
        ),
      ),
    );
  }
}
