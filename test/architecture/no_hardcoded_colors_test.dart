import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Feature code gets every colour from the theme (`context.appColors`,
/// `context.toneColors`, `AppColors.transparent`, or the colour scheme). The
/// word boundaries stop identifiers such as `toneColors.` from matching.
final RegExp _hardCoded = RegExp(r'\bColor\(0x|\bColors\.');

void main() {
  test('feature code never hard-codes a colour', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_hardCoded.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use context.appColors / context.toneColors / AppColors.transparent '
          'instead of a literal colour:\n${offenders.join('\n')}',
    );
  });

  test('the pattern matches real violations and ignores toneColors', () {
    expect(_hardCoded.hasMatch('color: Colors.red,'), isTrue);
    expect(_hardCoded.hasMatch('const Color(0xFF123456)'), isTrue);
    expect(_hardCoded.hasMatch('toneColors.fillFor(tone)'), isFalse);
    expect(_hardCoded.hasMatch('context.toneColors.focus'), isFalse);
  });
}
