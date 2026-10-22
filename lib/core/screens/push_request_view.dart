import 'dart:math' as math;

import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/shared/widgets/app_button.dart';
import 'package:altidial/shared/widgets/ring_mark.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../theme/app_space.dart';
import '../widgets/animated_gradient_background.dart';

/// What the push-request screen shows: the app's ring mark as a logo on the
/// shared background, and the question with Yes and Skip straight on it, over
/// the dark fade that rises from the bottom edge.
///
/// Portrait puts the logo at the exact centre of the screen. Landscape has no
/// room for that, so it goes at the top. Either way it shrinks before it
/// would touch the text.
///
/// `PushRequestScreen` decides what Yes and Skip do; this only draws.
class PushRequestView extends StatelessWidget {
  const PushRequestView({
    super.key,
    required this.onAllow,
    required this.onSkip,
  });

  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return AnimatedGradientBackground(
      colors: AppConfig.backgroundGradientColors,
      child: CustomMultiChildLayout(
        delegate: _PushRequestLayout(
          isLandscape: isLandscape,
          insets: MediaQuery.paddingOf(context),
        ),
        // Bottom to top: the fade under the logo, so the chick is never
        // dimmed, and the text over both.
        children: [
          LayoutId(
            id: _Slot.fade,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppConfig.pushRequestTextFadeGradient,
              ),
            ),
          ),
          LayoutId(id: _Slot.logo, child: const _AppLogo()),
          LayoutId(
            id: _Slot.text,
            child: _Text(
              isLandscape: isLandscape,
              onAllow: onAllow,
              onSkip: onSkip,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Slot { fade, logo, text }

/// Puts the text at the bottom, the fade behind it and the logo above it. The
/// text is measured first, since how tall it turns out to be (text size,
/// wrapped lines) decides how much room the logo has.
class _PushRequestLayout extends MultiChildLayoutDelegate {
  _PushRequestLayout({required this.isLandscape, required this.insets});

  final bool isLandscape;
  final EdgeInsets insets;

  static const double _textMaxWidth = 640;
  static const double _logoMaxSize = 320;

  /// Below this the logo is not worth drawing, so a screen too short to
  /// centre one this big gives up the centring instead.
  static const double _logoMinSize = 96;

  /// How far above the text the dark fade starts to rise.
  static const double _fadeLead = 72;

  @override
  void performLayout(Size size) {
    final sideMargin = isLandscape ? 60.0 : 30.0;
    final topMargin = insets.top + AppSpace.md;
    final bottomMargin = insets.bottom + AppSpace.xl;
    final gap = isLandscape ? AppSpace.md : AppSpace.lg;

    final textWidth = math.min(size.width - 2 * sideMargin, _textMaxWidth);
    final textSize = layoutChild(
      _Slot.text,
      BoxConstraints(
        minWidth: textWidth,
        maxWidth: textWidth,
        maxHeight: math.max(0, size.height - topMargin - bottomMargin),
      ),
    );
    final textTop = size.height - bottomMargin - textSize.height;
    positionChild(_Slot.text, Offset((size.width - textWidth) / 2, textTop));

    final fadeTop = math.max(0.0, textTop - _fadeLead);
    layoutChild(
      _Slot.fade,
      BoxConstraints.tight(Size(size.width, size.height - fadeTop)),
    );
    positionChild(_Slot.fade, Offset(0, fadeTop));

    // Everything from the top margin down to here is the logo's.
    final floor = textTop - gap;
    final double logoSize;
    final double logoTop;
    if (isLandscape) {
      logoSize = math.max(0, math.min(floor - topMargin, _logoMaxSize));
      logoTop = topMargin;
    } else {
      final wanted = math.min(size.width * 0.62, _logoMaxSize);
      // Centred on the screen, the logo reaches as far below the centre line
      // as above it, so the room under that line caps its size.
      final centred = math.min(wanted, 2 * (floor - size.height / 2));
      if (centred >= _logoMinSize) {
        logoSize = centred;
        logoTop = (size.height - centred) / 2;
      } else {
        logoSize = math.max(0, math.min(_logoMinSize, floor - topMargin));
        logoTop = floor - logoSize;
      }
    }
    layoutChild(_Slot.logo, BoxConstraints.tight(Size.square(logoSize)));
    positionChild(_Slot.logo, Offset((size.width - logoSize) / 2, logoTop));
  }

  @override
  bool shouldRelayout(_PushRequestLayout old) =>
      old.isLandscape != isLandscape || old.insets != insets;
}

/// The app's ring mark, with no halo behind it.
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RingMarkPainter(
        colors: [
          ToneColors.dark.focus.solid,
          ToneColors.dark.life.solid,
          ToneColors.dark.inbox.solid,
        ],
      ),
    );
  }
}

/// The question, Yes and Skip. Scrolls, rather than overflowing, when the
/// system text is so large that it does not fit the screen.
class _Text extends StatelessWidget {
  const _Text({
    required this.isLandscape,
    required this.onAllow,
    required this.onSkip,
  });

  final bool isLandscape;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Text(
              'Allow notifications about bonuses and promos',
              style: TextStyle(
                fontSize: isLandscape ? 22 : 20,
                fontWeight: FontWeight.w600,
                color: AppConfig.pushRequestTitleColor,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            child: Text(
              'Stay tuned with best offers from our casino',
              style: TextStyle(
                fontSize: isLandscape ? 19 : 17,
                fontWeight: FontWeight.w500,
                color: AppConfig.pushRequestSkipTextColor,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isLandscape ? AppSpace.lg : AppSpace.xl),
          SizedBox(
            width: double.infinity,
            height: isLandscape ? 48 : 64,
            child: AppButton(label: 'Yes', onPressed: onAllow),
          ),
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            height: isLandscape ? 40 : 50,
            child: ElevatedButton(
              onPressed: onSkip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppConfig.pushRequestSkipTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
