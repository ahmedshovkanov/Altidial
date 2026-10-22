import 'package:flutter/material.dart';

/// Neutral colours and elevation. Tone colours live in `ToneColors`. Colour on
/// screen only ever means a tone, so everything here is deliberately neutral.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.page,
    required this.surface,
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.outline,
    required this.danger,
    required this.nightTint,
  });

  /// A fully transparent colour. Feature code may not hard-code colours, so it
  /// uses this when it needs "no fill".
  static const Color transparent = Color(0x00000000);

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    page: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF17141F),
    onInk: Color(0xFFFFFFFF),
    muted: Color(0xFF5E5B6B),
    outline: Color(0xFFE4E4EA),
    danger: Color(0xFFC4261B),
    nightTint: Color(0x144A6FA5),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    page: Color(0xFF0F0F14),
    surface: Color(0xFF1A1A22),
    ink: Color(0xFFF4F4F8),
    onInk: Color(0xFF17141F),
    muted: Color(0xFFA7A5B5),
    outline: Color(0xFF2C2C38),
    danger: Color(0xFFFF6B63),
    nightTint: Color(0x1F7C9CFF),
  );

  final Brightness brightness;

  /// The page background.
  final Color page;

  /// Cards, the dial face, and sheets.
  final Color surface;

  /// Text, buttons, and the selected tab.
  final Color ink;

  /// Text on [ink].
  final Color onInk;

  /// Secondary text.
  final Color muted;

  /// Hairlines. Decorative only.
  final Color outline;

  /// Delete and error.
  final Color danger;

  /// The faint tint over night hours on the dial face. Decorative only.
  final Color nightTint;

  bool get isDark => brightness == Brightness.dark;

  /// Soft shadow under cards. Dark mode uses a hairline border instead.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ];

  /// Shadow that raises the dial face off the page.
  List<BoxShadow> get faceShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ];

  /// Shadow under the floating tab bar.
  List<BoxShadow> get barShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: ink.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? page,
    Color? surface,
    Color? ink,
    Color? onInk,
    Color? muted,
    Color? outline,
    Color? danger,
    Color? nightTint,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      page: page ?? this.page,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      muted: muted ?? this.muted,
      outline: outline ?? this.outline,
      danger: danger ?? this.danger,
      nightTint: nightTint ?? this.nightTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      nightTint: Color.lerp(nightTint, other.nightTint, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.brightness == brightness &&
      other.page == page &&
      other.surface == surface &&
      other.ink == ink &&
      other.onInk == onInk &&
      other.muted == muted &&
      other.outline == outline &&
      other.danger == danger &&
      other.nightTint == nightTint;

  @override
  int get hashCode => Object.hash(
    brightness,
    page,
    surface,
    ink,
    onInk,
    muted,
    outline,
    danger,
    nightTint,
  );
}

extension AppColorsContext on BuildContext {
  AppColors get appColors {
    final colors = Theme.of(this).extension<AppColors>();
    if (colors == null) {
      throw StateError(
        'AppColors is missing from the theme. Build the app with '
        'AppTheme.light or AppTheme.dark.',
      );
    }
    return colors;
  }
}
