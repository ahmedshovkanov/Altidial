import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/data/repositories/reflections_repository.dart';
import 'package:energy_clock/features/reflections/model/reflection.dart';
import 'package:flutter/material.dart';

class ReflectionRowTile extends StatelessWidget {
  const ReflectionRowTile({required this.item, required this.onTap, super.key});

  final ReflectedSession item;
  final VoidCallback onTap;

  Widget _dots(BuildContext context, int? value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value != null && i <= value
                  ? context.toneColors.paletteFor(item.tone).solid
                  : context.appColors.outline,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = item.session;
    final reflected = isReflected(
      energyRating: s.energyRating,
      focusRating: s.focusRating,
      tags: s.tags,
      note: s.note,
    );
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.toneColors.paletteFor(item.tone).solid,
        ),
      ),
      title: Text(item.eventTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatDurationMinutes((s.activeSeconds / 60).round())} · '
            '${item.tone.label}',
          ),
          const SizedBox(height: 2),
          if (!reflected)
            Text(Strings.reflectionsNotReflected, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.muted))
          else ...[
            Row(children: [Text(Strings.reflectionsEnergyShort), const SizedBox(width: 2), _dots(context, s.energyRating), const SizedBox(width: AppSpacing.sm), Text(Strings.reflectionsFocusShort), const SizedBox(width: 2), _dots(context, s.focusRating)]),
            if (s.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: [for (final t in s.tags) Chip(label: Text(Strings.tagLabel(t)), visualDensity: VisualDensity.compact)],
              ),
            if (s.note != null && s.note!.isNotEmpty)
              Text(s.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}