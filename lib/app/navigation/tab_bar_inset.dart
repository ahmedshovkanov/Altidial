import 'package:flutter/widgets.dart';

/// Tells screens how much bottom space the floating tab bar covers, so they can
/// pad their content. Zero when there is no tab shell above.
class TabBarInset extends InheritedWidget {
  const TabBarInset({required this.height, required super.child, super.key});

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabBarInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(TabBarInset oldWidget) => oldWidget.height != height;
}
