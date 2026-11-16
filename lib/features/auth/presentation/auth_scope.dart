import 'package:flutter/widgets.dart';

import '../application/auth_session_controller.dart';

class AuthScope extends InheritedNotifier<AuthSessionController> {
  const AuthScope({
    required AuthSessionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AuthSessionController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing above this context.');
    return scope!.notifier!;
  }

  static AuthSessionController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AuthScope>();
    final scope = element?.widget as AuthScope?;
    assert(scope != null, 'AuthScope is missing above this context.');
    return scope!.notifier!;
  }
}
