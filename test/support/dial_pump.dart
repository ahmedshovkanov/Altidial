import 'package:flutter_test/flutter_test.dart';

/// Pumps a bounded number of frames instead of calling [WidgetTester.pumpAndSettle].
///
/// A [DialView] on an empty, editable day never settles: its hint arc pulses
/// forever (unless the test turns reduced motion on), so `pumpAndSettle` spins
/// until the test harness gives up. These pumps total 100ms of fake time —
/// enough for the events stream to deliver and for tap handlers to rebuild.
Future<void> pumpDial(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
