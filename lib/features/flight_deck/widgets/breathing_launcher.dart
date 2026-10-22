// lib/features/flight_deck/widgets/breathing_launcher.dart
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/features/flight_deck/breathing/breathing_screen.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';

/// The Flight Deck's top entry point into the full-screen breathing minigame.
/// It follows the hub-card pattern: an `AppCard` that pushes a route.
class BreathingLauncher extends StatelessWidget {
  const BreathingLauncher({super.key});

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BreathingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: Strings.deckBreatheTitle,
      excludeSemantics: true,
      onTap: () => _open(context),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () => _open(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.page,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.air, color: colors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Strings.deckBreatheTitle,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(Strings.deckBreatheHint,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
