import 'dart:async';

import 'package:energy_clock/app/navigation/tab_dial_icon.dart';
import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tokens.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/shared/layout/content_width.dart';
import 'package:energy_clock/shared/widgets/press_scale.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The floating pill that switches between the five tabs. The selected tab is
/// an ink pill with its icon and label; the others show only their icon.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  static const double height = 64;
  static const double bottomMargin = 12;
  static const int tabCount = 5;

  static const List<String> _labels = [
    Strings.tabClock,
    Strings.projectsTitle,
    Strings.tabCalendar,
    Strings.tabProfile,
    Strings.tabDeck,
  ];

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  Widget _icon(int index, bool selected, Color color) => switch (index) {
    0 => TabDialIcon(selected: selected, color: color),
    1 => Icon(selected ? CupertinoIcons.folder_fill : CupertinoIcons.folder, color: color, size: 24),
    2 => Icon(CupertinoIcons.calendar, color: color, size: 24),
    3 => Icon(
      selected ? CupertinoIcons.person_fill : CupertinoIcons.person,
      color: color,
      size: 24,
    ),
    _ => Icon(CupertinoIcons.airplane, color: color, size: 24),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ContentWidth(
      maxWidth: ContentWidths.tabBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        // Tab labels are short and the bar is a fixed size, so they scale up
        // to 120% and no further.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.surface,
              shape: StadiumBorder(
                side: colors.isDark
                    ? BorderSide(color: colors.outline)
                    : BorderSide.none,
              ),
              shadows: colors.barShadow,
            ),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    for (var i = 0; i < tabCount; i++)
                      Expanded(
                        flex: i == selectedIndex ? 2 : 1,
                        child: _TabItem(
                          key: ValueKey('tab-$i'),
                          label: _labels[i],
                          position: i + 1,
                          selected: i == selectedIndex,
                          icon: (color) => _icon(i, i == selectedIndex, color),
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.position,
    required this.selected,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final int position;
  final bool selected;
  final Widget Function(Color color) icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = selected ? colors.onInk : colors.muted;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: selected,
      label: Strings.tabSemantics(label, position, AppTabBar.tabCount),
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        onTap: () {
          if (!selected) unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.base,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: selected ? colors.ink : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon(foreground),
              if (selected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge!.copyWith(color: foreground),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
