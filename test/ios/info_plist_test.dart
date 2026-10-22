import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `<string>` values inside the array that follows [key].
List<String> stringsIn(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist);
  if (match == null) fail('Info.plist has no $key array');
  return [
    for (final m in RegExp(
      r'<string>(.*?)</string>',
    ).allMatches(match.group(1)!))
      m.group(1)!,
  ];
}

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('the iPad lists all four orientations, which App Store Connect '
      'requires for multitasking (ITMS-90474)', () {
    expect(stringsIn(plist, 'UISupportedInterfaceOrientations~ipad').toSet(), {
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationPortraitUpsideDown',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    });
  });

  test('the iPhone stays portrait-only', () {
    expect(stringsIn(plist, 'UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
    ]);
  });

  test('the app is not forced to full screen, so multitasking stays on', () {
    expect(plist.contains('UIRequiresFullScreen'), isFalse);
  });

  test('the app is named Altidial and uses the Altidial bundle id', () {
    expect(
      plist,
      contains('<key>CFBundleDisplayName</key>\n\t<string>Altidial</string>'),
    );
    expect(
      plist,
      contains('<key>CFBundleName</key>\n\t<string>Altidial</string>'),
    );
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.nolanbouchet.altdial;'),
    );
    expect(
      project,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.nolanbouchet.altdial.RunnerTests;',
      ),
    );
    expect(project, isNot(contains('com.selfloop.energyClock')));
  });

  test('every build configuration targets both iPhone and iPad', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final families = RegExp(
      r'TARGETED_DEVICE_FAMILY = "([^"]*)";',
    ).allMatches(project).map((m) => m.group(1)).toList();
    expect(families, isNotEmpty);
    expect(families.toSet(), {'1,2'});
  });
}
