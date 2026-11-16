import 'package:flutter/widgets.dart';

import 'ads_controller.dart';

class AdsScope extends InheritedNotifier<AdsController> {
  const AdsScope({
    required AdsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AdsController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdsScope>();
    assert(scope != null, 'AdsScope is missing above this context.');
    return scope!.notifier!;
  }

  static AdsController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AdsScope>();
    final scope = element?.widget as AdsScope?;
    assert(scope != null, 'AdsScope is missing above this context.');
    return scope!.notifier!;
  }
}
