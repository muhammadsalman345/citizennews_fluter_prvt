import 'package:flutter/widgets.dart';

import 'localization_controller.dart';

class LocalizationScope extends InheritedNotifier<LocalizationController> {
  const LocalizationScope({
    required LocalizationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LocalizationController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocalizationScope>();
    assert(scope != null, 'LocalizationScope is missing above this context.');
    return scope!.notifier!;
  }

  static LocalizationController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<LocalizationScope>();
    final scope = element?.widget as LocalizationScope?;
    assert(scope != null, 'LocalizationScope is missing above this context.');
    return scope!.notifier!;
  }
}
