import 'dart:io';

import 'package:altidial/app/onboarding/onboarding_providers.dart';
import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/app_config.dart';
import 'package:altidial/core/links/open_link.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/features/progress/widgets/profile_section.dart';
import 'package:altidial/shared/widgets/adaptive_choice.dart';
import 'package:altidial/shared/widgets/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme, focus target, first day of week, recalculate, export and erase
/// (spec §9.7). Erasing returns the app to onboarding.
class SettingsCard extends ConsumerWidget {
  const SettingsCard({super.key});

  static const List<int> _targetChoices = [60, 90, 120, 180, 240, 300, 360];

  String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Strings.themeSystem,
    ThemeMode.light => Strings.themeLight,
    ThemeMode.dark => Strings.themeDark,
  };

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<ThemeMode>(
      context,
      title: Strings.settingsTheme,
      cancelLabel: Strings.cancel,
      options: [
        for (final mode in ThemeMode.values)
          ChoiceOption(label: _themeLabel(mode), value: mode),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref.read(themeModeProvider.notifier).set(picked);
  }

  Future<void> _pickTarget(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<int>(
      context,
      title: Strings.settingsFocusTarget,
      cancelLabel: Strings.cancel,
      options: [
        for (final minutes in _targetChoices)
          ChoiceOption(label: formatDurationMinutes(minutes), value: minutes),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref.read(focusTargetProvider.notifier).set(picked);
  }

  Future<void> _pickFirstDay(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<int>(
      context,
      title: Strings.settingsFirstDay,
      cancelLabel: Strings.cancel,
      options: [
        ChoiceOption(label: Strings.weekdayLong[0], value: DateTime.monday),
        ChoiceOption(label: Strings.weekdayLong[6], value: DateTime.sunday),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref.read(firstDayOfWeekProvider.notifier).set(picked);
  }

  Future<void> _recalculate(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: Strings.settingsRecalculateTitle,
      body: Strings.settingsRecalculateBody,
      confirmLabel: Strings.settingsRecalculateConfirm,
      cancelLabel: Strings.cancel,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(progressRepositoryProvider).recalculateAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(Strings.settingsRecalculated)));
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(exportRepositoryProvider);
      final json = await repository.buildJson();
      final path = await repository.writeTempFile(json);
      try {
        await ref
            .read(shareServiceProvider)
            .shareFile(path, subject: Strings.settingsExportSubject);
      } finally {
        await File(path).delete();
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.settingsExportFailed)),
      );
    }
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: Strings.settingsEraseTitle,
      body: Strings.settingsEraseBody,
      confirmLabel: Strings.settingsEraseConfirm,
      cancelLabel: Strings.cancel,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(appDatabaseProvider).resetAll();
    ref.invalidate(themeModeProvider);
    ref.invalidate(focusTargetProvider);
    ref.invalidate(firstDayOfWeekProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(Strings.settingsErased)));
    ref.invalidate(onboardingDoneProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider).valueOrNull;
    final target = ref.watch(focusTargetProvider).valueOrNull;
    final firstDay = ref.watch(firstDayOfWeekProvider).valueOrNull;
    return ProfileSection(
      title: Strings.settingsTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            key: const ValueKey('settings-theme'),
            label: Strings.settingsTheme,
            value: theme == null ? null : _themeLabel(theme),
            onTap: () => _pickTheme(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-focus-target'),
            label: Strings.settingsFocusTarget,
            value: target == null ? null : formatDurationMinutes(target),
            onTap: () => _pickTarget(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-first-day'),
            label: Strings.settingsFirstDay,
            value: firstDay == null
                ? null
                : Strings.weekdayLong[firstDay - DateTime.monday],
            onTap: () => _pickFirstDay(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-recalculate'),
            label: Strings.settingsRecalculate,
            onTap: () => _recalculate(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-export'),
            label: Strings.settingsExport,
            onTap: () => _export(context, ref),
          ),
          _Row(
            key: const ValueKey('settings-privacy'),
            label: Strings.settingsPrivacy,
            onTap: () => openUrl(AppConfig.privacyPolicyUrl),
          ),
          _Row(
            key: const ValueKey('settings-erase'),
            label: Strings.settingsErase,
            destructive: true,
            onTap: () => _erase(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.value,
    this.destructive = false,
    super.key,
  });

  final String label;
  final String? value;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
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
            if (value != null) Text(value!, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.xs),
            Icon(CupertinoIcons.chevron_right, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
