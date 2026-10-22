import 'package:flutter/material.dart';

/// A section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  /// The trailing label sits in a row that also has to hold the title, so its
  /// text stops growing at this scale. Without it the Stats adherence label
  /// overflowed narrow windows at large text sizes.
  static const double _maxTrailingTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (trailing != null)
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: _maxTrailingTextScale,
            child: trailing,
          ),
      ],
    );
  }
}
