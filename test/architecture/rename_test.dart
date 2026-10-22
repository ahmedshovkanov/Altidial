import 'dart:io';

import 'package:altidial/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Dart package is altidial', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains(RegExp(r'^name: altidial$', multiLine: true)));
  });

  test('no Dart source imports energy_clock', () {
    final oldPackage = '${'package'}:${'energy_clock'}/';
    final offenders = <String>[];
    for (final root in ['lib', 'test', 'tool']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains(oldPackage)) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the app title is Altidial', () {
    expect(Strings.appTitle, 'Altidial');
    expect(Strings.settingsExportSubject, 'Altidial export');
  });
}
