import 'package:altidial/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the bundled Nunito font is loaded in tests', (tester) async {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Hello',
        style: AppTypography.displayTime(100).copyWith(fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Flutter's test fallback font draws every glyph as a 1-em box (5 × 20 = 100).
    expect(painter.width, isNot(100));
  });
}
