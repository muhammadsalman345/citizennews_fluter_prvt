import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../domain/account_access.dart';
import '../domain/auth_profile.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController(this.service, {this.startupError});

  factory AuthSessionController.unconfigured() =>
      AuthSessionController(AuthService.unconfigured());

  final AuthService service;
  final String? startupError;
  StreamSubscription<AuthState>? _subscription;
  int _loadVersion = 0;

  bool _ready = false;
  bool _loadingProfile = false;
  bool _passwordRecovery = false;
  User? _user;
  AuthProfile? _profile;
  Set<String> _roles = const {};
  AccountAccessStatus _accountStatus = AccountAccessStatus.unknown;
  String? _authorizationError;

  bool get ready => _ready;
  bool get configured => service.isConfigured;
  bool get loadingProfile => _loadingProfile;
  bool get passwordRecovery => _passwordRecovery;
  bool get isSignedIn => _user != null;
  bool get isReporter =>
      isActive &&
      (_roles.contains('reporter') || _roles.contains('trusted_reporter'));
  bool get isAdmin =>
      isActive &&
      (_roles.contains('admin') || _roles.contains('super_admin'));
  bool get isSuperAdmin => isActive && _roles.contains('super_admin');
  bool get isActive => _accountStatus == AccountAccessStatus.active;
  bool get isSuspended => _accountStatus == AccountAccessStatus.suspended;
  bool get authorizationReady => !_loadingProfile;
  AccountAccessStatus get accountStatus => _accountStatus;
  String? get authorizationError => _authorizationError;
  User? get user => _user;
  AuthProfile? get profile => _profile;
  Set<String> get roles => Set.unmodifiable(_roles);
  String get displayName =>
      _profile?.fullName ??
      (_user?.userMetadata?['full_name'] as String?)?.trim() ??
      'Reader';

  Future<void> initialize() async {
    final client = service.client;
    if (client == null) {
      _ready = true;
      notifyListeners();
      return;
    }
    _subscription = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecovery = true;
      }
      unawaited(syncFromClient());
    });
    await syncFromClient();
    _ready = true;
    notifyListeners();
  }

  Future<void> syncFromClient() async {
    final client = service.client;
    final nextUser = client?.auth.currentUser;
    final version = ++_loadVersion;
    _user = nextUser;
    if (nextUser == null || client == null) {
      _profile = null;
      _roles = const {};
      _accountStatus = AccountAccessStatus.unknown;
      _authorizationError = null;
      _loadingProfile = false;
      notifyListeners();
      return;
    }

    _profile ??= AuthProfile.fromUser(nextUser);
    _loadingProfile = true;
    _authorizationError = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        client
            .from('profiles')
            .select('id,full_name,username,bio,avatar_url,city_id')
            .eq('id', nextUser.id)
            .single(),
        client.rpc<dynamic>('my_roles'),
        client
            .from('account_status')
            .select('status')
            .eq('user_id', nextUser.id)
            .maybeSingle(),
      ]);
      if (version != _loadVersion || _user?.id != nextUser.id) return;
      _profile = AuthProfile.fromJson(
        Map<String, dynamic>.from(results[0] as Map),
      );
      _roles = (results[1] as List? ?? const [])
          .map((role) => role.toString())
          .toSet();
      final status = (results[2] as Map?)?['status']?.toString();
      _accountStatus = switch (status) {
        'active' => AccountAccessStatus.active,
        'suspended' => AccountAccessStatus.suspended,
        _ => AccountAccessStatus.unknown,
      };
    } catch (error) {
      if (version == _loadVersion) {
        _profile ??= AuthProfile.fromUser(nextUser);
        _roles = const {};
        _accountStatus = AccountAccessStatus.unknown;
        _authorizationError =
            'We could not verify your account permissions. Please retry.';
      }
    } finally {
      if (version == _loadVersion) {
        _loadingProfile = false;
        notifyListeners();
      }
    }
  }

  void finishPasswordRecovery() {
    if (!_passwordRecovery) return;
    _passwordRecovery = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await service.signOut();
    _user = null;
    _profile = null;
    _roles = const {};
    _accountStatus = AccountAccessStatus.unknown;
    _authorizationError = null;
    _passwordRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
