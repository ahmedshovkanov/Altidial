import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/debug/debug_actions.dart';
import 'package:altidial/debug/debug_providers.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/section_header.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugSection extends ConsumerWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(debugModeProvider).valueOrNull ?? false;
    if (!active) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: Strings.debugTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(Strings.debugStatusActive, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Strings.debugStatusHint,
              style: theme.textTheme.bodyMedium!.copyWith(color: colors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DebugRow(
              label: Strings.debugRegenerate,
              onTap: () => regenerateDemo(context, ref),
            ),
            _DebugRow(
              label: Strings.debugExit,
              destructive: true,
              onTap: () => exitDebug(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: destructive ? colors.danger : null,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
