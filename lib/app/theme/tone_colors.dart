import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// The four colours one tone needs.
@immutable
class TonePalette {
  const TonePalette({
    required this.solid,
    required this.onSolid,
    required this.soft,
    required this.deep,
  });

  /// Arcs, the Now card, and day-load segments.
  final Color solid;

  /// Text drawn on [solid]. White on Focus; near-black on Life and Inbox,
  /// because white is too faint on green and orange.
  final Color onSolid;

  /// Chip background.
  final Color soft;

  /// Text on [soft] or on the page.
  final Color deep;

  static TonePalette lerp(TonePalette a, TonePalette b, double t) {
    return TonePalette(
      solid: Color.lerp(a.solid, b.solid, t)!,
      onSolid: Color.lerp(a.onSolid, b.onSolid, t)!,
      soft: Color.lerp(a.soft, b.soft, t)!,
      deep: Color.lerp(a.deep, b.deep, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TonePalette &&
      other.solid == solid &&
      other.onSolid == onSolid &&
      other.soft == soft &&
      other.deep == deep;

  @override
  int get hashCode => Object.hash(solid, onSolid, soft, deep);
}

/// Per-tone colours. Held in a theme extension rather than on [Tone] itself so
/// that light and dark palettes can differ while the tone identity stays a pure
/// domain concept.
@immutable
class ToneColors extends ThemeExtension<ToneColors> {
  const ToneColors({
    required this.focus,
    required this.life,
    required this.inbox,
  });

  static const ToneColors light = ToneColors(
    focus: TonePalette(
      solid: Color(0xFF6D4AFF),
      onSolid: Color(0xFFFFFFFF),
      soft: Color(0xFFECE8FF),
      deep: Color(0xFF4A2FD1),
    ),
    life: TonePalette(
      solid: Color(0xFF14A85A),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFFDDF7EA),
      deep: Color(0xFF0E7A47),
    ),
    inbox: TonePalette(
      solid: Color(0xFFF26B00),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFFFFEBD6),
      deep: Color(0xFF9A4D00),
    ),
  );

  static const ToneColors dark = ToneColors(
    focus: TonePalette(
      solid: Color(0xFF8E78FF),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFF2A2450),
      deep: Color(0xFFC9BEFF),
    ),
    life: TonePalette(
      solid: Color(0xFF34D399),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFF16382B),
      deep: Color(0xFFA7F3D0),
    ),
    inbox: TonePalette(
      solid: Color(0xFFFFA040),
      onSolid: Color(0xFF17141F),
      soft: Color(0xFF402A12),
      deep: Color(0xFFFFD2A1),
    ),
  );

  final TonePalette focus;
  final TonePalette life;
  final TonePalette inbox;

  TonePalette paletteFor(Tone tone) => switch (tone) {
    Tone.focus => focus,
    Tone.life => life,
    Tone.inbox => inbox,
  };

  /// The arc colour. Kept as a wrapper so existing call sites keep working.
  Color fillFor(Tone tone) => paletteFor(tone).solid;

  /// Text drawn on the arc colour.
  Color labelFor(Tone tone) => paletteFor(tone).onSolid;

  Color softFor(Tone tone) => paletteFor(tone).soft;

  Color deepFor(Tone tone) => paletteFor(tone).deep;

  @override
  ToneColors copyWith({
    TonePalette? focus,
    TonePalette? life,
    TonePalette? inbox,
  }) {
    return ToneColors(
      focus: focus ?? this.focus,
      life: life ?? this.life,
      inbox: inbox ?? this.inbox,
    );
  }

  @override
  ToneColors lerp(ThemeExtension<ToneColors>? other, double t) {
    if (other is! ToneColors) return this;
    return ToneColors(
      focus: TonePalette.lerp(focus, other.focus, t),
      life: TonePalette.lerp(life, other.life, t),
      inbox: TonePalette.lerp(inbox, other.inbox, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ToneColors &&
      other.focus == focus &&
      other.life == life &&
      other.inbox == inbox;

  @override
  int get hashCode => Object.hash(focus, life, inbox);
}

extension ToneColorsContext on BuildContext {
  ToneColors get toneColors {
    final colors = Theme.of(this).extension<ToneColors>();
    if (colors == null) {
      throw StateError(
        'ToneColors is missing from the theme. Build the app with '
        'AppTheme.light or AppTheme.dark.',
      );
    }
    return colors;
  }
}
