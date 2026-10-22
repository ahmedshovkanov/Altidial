import 'dart:async';

import 'package:altidial/app/theme/app_colors.dart';
import 'package:altidial/app/theme/tokens.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/data/notifications/notification_permission.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/notification_scheduler.dart';
import 'package:altidial/shared/widgets/adaptive_choice.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:altidial/shared/widgets/section_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The Notifications group of Profile's settings: four per-type toggles, the
/// morning-time row, and the OS-off state (spec §10). Step 4's Profile shell
/// keeps this widget and adds its own sections around it.
class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key});

  /// Morning choices, minutes since midnight: 06:00–10:00 in 30-minute steps.
  static const List<int> morningChoices = [
    360, 390, 420, 450, 480, 510, 540, 570, 600,
  ];

  static String _morningLabel(int minutes) => DateFormat('h:mm a').format(
    DateTime(2026, 1, 1).add(Duration(minutes: minutes)),
  );

  Future<void> _flip({
    required BuildContext context,
    required WidgetRef ref,
    required String key,
    required bool value,
  }) async {
    final settings = ref.read(settingsRepositoryProvider);
    if (!value) {
      await settings.setBool(key, false);
      ref.invalidate(_togglesProvider);
      unawaited(ref.read(notificationSchedulerProvider).reconcile());
      return;
    }
    final granted = await ensureNotificationPermission(
      service: ref.read(notificationServiceProvider),
      settings: settings,
    );
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Strings.notificationsDenied),
          action: SnackBarAction(
            label: Strings.notificationsOpenSettings,
            onPressed:
                () => unawaited(
                  ref.read(notificationServiceProvider).openSettings(),
                ),
          ),
        ),
      );
      return;
    }
    await settings.setBool(key, true);
    ref.invalidate(_togglesProvider);
    unawaited(ref.read(notificationSchedulerProvider).reconcile());
  }

  Future<void> _pickMorning(BuildContext context, WidgetRef ref) async {
    final picked = await chooseOne<int>(
      context,
      title: Strings.morningTimeLabel,
      cancelLabel: Strings.cancel,
      options: [
        for (final minutes in morningChoices)
          ChoiceOption(label: _morningLabel(minutes), value: minutes),
      ],
    );
    if (picked == null || !context.mounted) return;
    await ref
        .read(settingsRepositoryProvider)
        .setInt(morningReminderMinutesKey, picked);
    ref.invalidate(_togglesProvider);
    unawaited(ref.read(notificationSchedulerProvider).reconcile());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = ref.watch(_systemEnabledProvider);
    final prompted = ref.watch(_promptedProvider);
    return (system.when(
      data: (enabled) => enabled,
      loading: () => false,
      error: (_, _) => false,
    ) ||
            prompted.when(
              data: (p) => !p,
              loading: () => false,
              error: (_, _) => false,
            ))
        ? _Toggles(
            onFlip:
                (key, value) => _flip(
                  context: context,
                  ref: ref,
                  key: key,
                  value: value,
                ),
            onMorning: () => _pickMorning(context, ref),
          )
        : _OffState(
            onOpenSettings: () => unawaited(
              ref.read(notificationServiceProvider).openSettings(),
            ),
          );
  }
}

class _Toggles extends ConsumerWidget {
  const _Toggles({required this.onFlip, required this.onMorning});

  final Future<void> Function(String key, bool value) onFlip;
  final VoidCallback onMorning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggles = ref.watch(_togglesProvider);
    return toggles.when(
data: (state) {
        final colors = context.appColors;
        final theme = Theme.of(context);
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              SectionHeader(title: Strings.settingsNotifications),
              const SizedBox(height: AppSpacing.sm),
              _ToggleRow(
                rowKey: 'settings-notify-session',
                label: Strings.notifySessionEndLabel,
                value: state.session,
                onChanged:
                    (value) => onFlip(notifySessionEndKey, value),
              ),
              _ToggleRow(
                rowKey: 'settings-notify-event',
                label: Strings.notifyEventSoonLabel,
                value: state.event,
                onChanged: (value) => onFlip(notifyEventSoonKey, value),
              ),
              _ToggleRow(
                rowKey: 'settings-notify-roundup',
                label: Strings.notifyRoundupLabel,
                value: state.roundup,
                onChanged: (value) => onFlip(notifyRoundupKey, value),
              ),
              _ToggleRow(
                rowKey: 'settings-notify-morning',
                label: Strings.notifyMorningLabel,
                value: state.morning,
                onChanged: (value) => onFlip(notifyMorningKey, value),
              ),
              InkWell(
                key: const ValueKey('settings-morning-time'),
                onTap: state.morning ? onMorning : null,
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Strings.morningTimeLabel,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color:
                                state.morning ? null : colors.muted,
                          ),
                        ),
                      ),
                      Text(
                        NotificationSettingsSection._morningLabel(
                          state.minutes,
                        ),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: state.morning ? null : colors.muted,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 18,
                        color: colors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String rowKey;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The whole row toggles: a bigger target than the switch alone.
    return MergeSemantics(
      child: InkWell(
        key: ValueKey(rowKey),
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              CupertinoSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _OffState extends ConsumerWidget {
  const _OffState({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: InkWell(
        key: const ValueKey('settings-notifications-off'),
        onTap: onOpenSettings,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.notificationsOffTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.notificationsOffBody,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four toggle states plus the morning minutes, read together so the
/// section builds once.
final _togglesProvider = FutureProvider<
  ({bool session, bool event, bool roundup, bool morning, int minutes})
>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  return (
    session: await settings.getBool(notifySessionEndKey, defaultValue: true),
    event: await settings.getBool(notifyEventSoonKey, defaultValue: true),
    roundup: await settings.getBool(notifyRoundupKey, defaultValue: true),
    morning: await settings.getBool(notifyMorningKey, defaultValue: true),
    minutes:
        await settings.getInt(morningReminderMinutesKey) ??
        defaultMorningMinutes,
  );
});

final _systemEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(notificationServiceProvider).areEnabled();
});

/// Whether the user has been prompted for notification permission.
/// Used to show toggles (and prompt on enable) if not prompted yet,
/// or off-state row if already prompted and refused.
final _promptedProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  return await settings.getBool(notificationsPromptedKey);
});