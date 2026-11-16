import 'package:flutter/widgets.dart';

import '../application/location_controller.dart';

class LocationScope extends InheritedNotifier<LocationController> {
  const LocationScope({
    required LocationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LocationController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocationScope>();
    assert(scope != null, 'LocationScope is missing above this context.');
    return scope!.notifier!;
  }

  static LocationController read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<LocationScope>();
    final scope = element?.widget as LocationScope?;
    assert(scope != null, 'LocationScope is missing above this context.');
    return scope!.notifier!;
  }
}
