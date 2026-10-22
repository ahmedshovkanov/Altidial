import 'dart:async';

import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/reuse_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/shared/widgets/adaptive_dialog.dart';
import 'package:energy_clock/shared/widgets/app_card.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A bottom sheet of the saved day templates. Tapping one puts its events on
/// [day] and closes the sheet; the trash button deletes a template after a
/// confirmation. Only an empty day is offered this sheet (spec §7), and the
/// repository refuses a day that is not empty.
class TemplatePickerSheet extends ConsumerWidget {
  const TemplatePickerSheet({required this.day, super.key});

  final DateTime day;

  static Future<void> show(BuildContext context, {required DateTime day}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TemplatePickerSheet(day: day),
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    DayTemplate template,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(reuseRepositoryProvider)
          .applyTemplate(templateId: template.id, day: day);
      navigator.pop();
      unawaited(HapticFeedback.mediumImpact());
    } on DayNotEmptyException {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.dayNotEmpty)),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.applyFailed)),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DayTemplate template,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: Strings.deleteTemplateTitle,
      body: Strings.deleteTemplateBody,
      confirmLabel: Strings.delete,
      cancelLabel: Strings.cancel,
    );
    if (!confirmed) return;
    await ref.read(reuseRepositoryProvider).deleteTemplate(template.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.applyTemplate,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          templates.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text(Strings.templatesLoadFailed)),
            ),
            data: (list) => list.isEmpty
                ? const _EmptyState()
                : Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _TemplateTile(
                        template: list[index],
                        onApply: () => _apply(context, ref, list[index]),
                        onDelete: () => _delete(context, ref, list[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            Strings.templatesEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            Strings.templatesEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// One template: its name, a summary line with a dot per tone, and a trash
/// button. The name and summary are one button that applies the template.
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.onApply,
    required this.onDelete,
  });

  final DayTemplate template;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColors = context.toneColors;
    final colors = context.appColors;
    final summary = Strings.templateSummary(
      template.eventCount,
      formatDurationMinutes(template.totalMinutes),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: Strings.templateSemantics(
                template.name,
                Strings.eventCount(template.eventCount),
                spokenDurationMinutes(template.totalMinutes),
              ),
              excludeSemantics: true,
              onTap: onApply,
              child: PressScale(
                onTap: onApply,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              summary,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          for (final tone in template.tones)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: DecoratedBox(
                                key: ValueKey(
                                  'template-dot-${template.id}-${tone.name}',
                                ),
                                decoration: BoxDecoration(
                                  color: toneColors.fillFor(tone),
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox.square(dimension: 8),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(CupertinoIcons.trash, size: 20, color: colors.muted),
            tooltip: Strings.deleteTemplate,
            onPressed: onDelete,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}
