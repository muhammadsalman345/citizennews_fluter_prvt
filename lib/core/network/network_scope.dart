import 'package:flutter/widgets.dart';

import 'network_controller.dart';

class NetworkScope extends InheritedNotifier<NetworkController> {
  const NetworkScope({
    required NetworkController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static NetworkController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NetworkScope>();
    assert(scope != null, 'NetworkScope is missing above this context.');
    return scope!.notifier!;
  }

  static NetworkController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<NetworkScope>();
    final scope = element?.widget as NetworkScope?;
    assert(scope != null, 'NetworkScope is missing above this context.');
    return scope!.notifier!;
  }
}
