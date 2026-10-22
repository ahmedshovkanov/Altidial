import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';

/// The chrome every Profile section shares. A feature-local twin of the stats
/// section card — features never import each other, so the ten lines are
/// duplicated rather than shared.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    required this.title,
    required this.child,
    this.trailing,
    this.empty = false,
    this.emptyMessage = '',
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool empty;
  final String emptyMessage;
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
            child,
        ],
      ),
    );
  }
}
