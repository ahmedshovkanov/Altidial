import 'package:altidial/shared/layout/window_class.dart';
import 'package:flutter/widgets.dart';

/// Single column on narrow windows, two columns from medium up.
class StatsLayout {
  const StatsLayout({required this.twoColumn});

  factory StatsLayout.of(BuildContext context) =>
      StatsLayout(twoColumn: context.windowClass != WindowClass.narrow);

  final bool twoColumn;
}
