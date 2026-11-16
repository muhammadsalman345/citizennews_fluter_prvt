import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class NetworkController extends ChangeNotifier with WidgetsBindingObserver {
  NetworkController({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;
  bool _online = true;
  bool _disposed = false;

  bool get initialized => _initialized;
  bool get online => _online;
  bool get offline => _initialized && !_online;

  Future<void> initialize() async {
    if (_subscription != null || _disposed) return;
    WidgetsBinding.instance.addObserver(this);
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('[CitizenNews Network] Initial status unavailable: $error');
      _initialized = true;
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return;
    _subscription = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[CitizenNews Network] Status update failed: $error');
      },
    );
  }

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('[CitizenNews Network] Status refresh failed: $error');
    }
  }

  void _apply(List<ConnectivityResult> results) {
    if (_disposed) return;
    final nextOnline = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final changed = !_initialized || nextOnline != _online;
    _initialized = true;
    _online = nextOnline;
    if (changed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
