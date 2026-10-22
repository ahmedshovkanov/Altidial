import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/widgets/app_button.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The one-time note shown when notifications are off: the timer works, but
/// nothing will tell the person when time is up while the app is closed.
class AlertsBanner extends StatelessWidget {
  const AlertsBanner({
    required this.onOpenSettings,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.bell_slash_fill, color: colors.muted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.alertsOffTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Strings.alertsOffBody,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey('alerts-open-settings'),
                  label: Strings.openSettings,
                  variant: AppButtonVariant.secondary,
                  onPressed: onOpenSettings,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  key: const ValueKey('alerts-dismiss'),
                  label: Strings.dismiss,
                  variant: AppButtonVariant.secondary,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
