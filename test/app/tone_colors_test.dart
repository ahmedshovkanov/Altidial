import 'package:energy_clock/app/theme/app_colors.dart';
import 'package:energy_clock/app/theme/tone_colors.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';

void main() {
  final modes = {
    'light': (ToneColors.light, AppColors.light),
    'dark': (ToneColors.dark, AppColors.dark),
  };

  test('every tone has a distinct solid in both themes', () {
    for (final (tones, _) in modes.values) {
      final solids = Tone.values.map(tones.fillFor).toSet();
      expect(solids, hasLength(Tone.values.length));
    }
  });

  test('light and dark solids differ for every tone', () {
    for (final tone in Tone.values) {
      expect(
        ToneColors.light.fillFor(tone),
        isNot(ToneColors.dark.fillFor(tone)),
      );
    }
  });

  test('focus solid matches the specified light palette value', () {
    expect(ToneColors.light.fillFor(Tone.focus), const Color(0xFF6D4AFF));
    expect(ToneColors.light.fillFor(Tone.life), const Color(0xFF14A85A));
    expect(ToneColors.light.fillFor(Tone.inbox), const Color(0xFFF26B00));
  });

  test('every accessor reads the same palette', () {
    for (final tone in Tone.values) {
      final palette = ToneColors.light.paletteFor(tone);
      expect(ToneColors.light.fillFor(tone), palette.solid);
      expect(ToneColors.light.labelFor(tone), palette.onSolid);
      expect(ToneColors.light.softFor(tone), palette.soft);
      expect(ToneColors.light.deepFor(tone), palette.deep);
    }
  });

  test('lerp returns a ToneColors halfway between the palettes', () {
    final result = ToneColors.light.lerp(ToneColors.dark, 0.5);
    expect(result, isA<ToneColors>());
    expect(
      result.fillFor(Tone.focus),
      Color.lerp(
        ToneColors.light.fillFor(Tone.focus),
        ToneColors.dark.fillFor(Tone.focus),
        0.5,
      ),
    );
  });

  test('equality and hashCode follow the values', () {
    expect(ToneColors.light, ToneColors.light.copyWith());
    expect(ToneColors.light.hashCode, ToneColors.light.copyWith().hashCode);
    expect(ToneColors.light, isNot(ToneColors.dark));
  });

  test('copyWith replaces one palette', () {
    final replaced = ToneColors.light.copyWith(
      life: ToneColors.dark.paletteFor(Tone.life),
    );
    expect(
      replaced.paletteFor(Tone.life),
      ToneColors.dark.paletteFor(Tone.life),
    );
    expect(
      replaced.paletteFor(Tone.focus),
      ToneColors.light.paletteFor(Tone.focus),
    );
  });

  for (final entry in modes.entries) {
    group('${entry.key} contrast', () {
      final (tones, app) = entry.value;

      for (final tone in Tone.values) {
        test('${tone.label}: label on the arc is at least 4.5:1', () {
          expect(
            contrastRatio(tones.labelFor(tone), tones.fillFor(tone)),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('${tone.label}: the arc against the face is at least 3:1', () {
          expect(
            contrastRatio(tones.fillFor(tone), app.surface),
            greaterThanOrEqualTo(3),
          );
        });

        test('${tone.label}: chip text on its soft fill is at least 4.5:1', () {
          expect(
            contrastRatio(tones.deepFor(tone), tones.softFor(tone)),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('${tone.label}: deep text on the page is at least 4.5:1', () {
          expect(
            contrastRatio(tones.deepFor(tone), app.page),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    });
  }
}
