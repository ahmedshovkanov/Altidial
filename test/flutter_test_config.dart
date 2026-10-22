import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Nunito font for every test in this package. Without it,
/// Flutter's test environment draws every glyph as a solid box: text has
/// unrealistic widths and goldens show black rectangles instead of letters.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Nunito');
  for (final weight in const ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await loader.load();
  await testMain();
}
