import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';

/// The chrome every Stats section shares: a card, a header, then either an
/// empty-state message or the chart wrapped in its spoken summary.
class StatsSectionCard extends StatelessWidget {
  const StatsSectionCard({
    required this.title,
    required this.empty,
    required this.emptyMessage,
    required this.semanticsLabel,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool empty;
  final String emptyMessage;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, trailing: trailing),
          const SizedBox(height: AppSpacing.sm),
          if (empty)
            Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)
          else
            Semantics(
              label: semanticsLabel,
              excludeSemantics: true,
              child: child,
            ),
        ],
      ),
    );
  }
}
