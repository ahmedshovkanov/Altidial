import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'hop_panel.dart';

/// The only way to present an overlay. Supplies the scrim, the transition
/// and the panel frame so no overlay can drift off-style.
Future<T?> showHopOverlay<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget> actions = const [],
  bool dismissible = true,
  bool isMoment = false,
  double maxWidth = 520,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: title,
    barrierColor: AppColors.scrim,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            // Transparent so the panel's own surface colour paints the surface.
            // Without these a TextField or InkWell inside an overlay would
            // have no Material ancestor and would assert.
            type: MaterialType.transparency,
            child: HopPanel(
              title: title,
              body: body,
              actions: actions,
              onClose: dismissible ? () => Navigator.of(context).pop() : null,
              isMoment: isMoment,
              maxWidth: maxWidth,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
