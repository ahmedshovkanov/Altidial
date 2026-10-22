// test/features/flight_deck/calm_content_test.dart
import 'package:energy_clock/features/flight_deck/calm_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled set is 10 facts + 8 tips with unique comma-free ids', () {
    expect(calmCards, hasLength(18));
    expect(calmCards.where((c) => c.kind == CalmKind.fact), hasLength(10));
    expect(calmCards.where((c) => c.kind == CalmKind.tip), hasLength(8));
    final ids = calmCards.map((c) => c.id).toList();
    expect(ids.toSet(), hasLength(18));
    expect(ids.every((id) => !id.contains(',') && id.isNotEmpty), isTrue);
    expect(calmCards.every((c) => c.title.isNotEmpty && c.body.isNotEmpty), isTrue);
  });
}
