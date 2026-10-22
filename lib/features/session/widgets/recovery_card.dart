import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/shared/widgets/app_button.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// Shown in place of the controls when the app is opened and finds a session
/// that was left running (spec §6.5): pick it up again, or close it out.
class RecoveryCard extends StatelessWidget {
  const RecoveryCard({
    required this.title,
    required this.elapsed,
    required this.onResume,
    required this.onCloseOut,
    super.key,
  });

  /// The event's title.
  final String title;

  /// How long the session has been going, already formatted.
  final String elapsed;

  final VoidCallback onResume;
  final VoidCallback onCloseOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.recoveryTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.recoveryBody(title, elapsed),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const ValueKey('recovery-resume'),
            label: Strings.recoveryResume,
            onPressed: onResume,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            key: const ValueKey('recovery-close-out'),
            label: Strings.recoveryCloseOut,
            variant: AppButtonVariant.secondary,
            onPressed: onCloseOut,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.recoveryCloseOutHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
