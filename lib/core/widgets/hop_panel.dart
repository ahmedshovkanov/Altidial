import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'hop_surface.dart';
import 'accent_ornament.dart';

/// The single frame used by EVERY overlay in the app. Overlays supply a
/// title, a body and actions — never their own chrome. This is what keeps
/// the app on one design.
class HopPanel extends StatelessWidget {
  const HopPanel({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.onClose,
    this.isMoment = false,
    this.maxWidth = 520,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onClose;

  /// Run result, level-up, daily reward. Only these earn accent chrome.
  final bool isMoment;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: HopSurface(
          elevation: Elevation.panel,
          isMoment: isMoment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title(context),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      iconSize: 28,
                      constraints: const BoxConstraints(
                        minWidth: AppTheme.minTapTarget,
                        minHeight: AppTheme.minTapTarget,
                      ),
                      icon: const Icon(Icons.close, color: AppColors.accent),
                    ),
                ],
              ),
              Flexible(child: SingleChildScrollView(child: body)),
              if (actions.isNotEmpty) ...[
                RuleDivider(emphasis: isMoment),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
