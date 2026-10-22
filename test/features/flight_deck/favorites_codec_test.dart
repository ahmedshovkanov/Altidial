// test/features/flight_deck/favorites_codec_test.dart
import 'package:altidial/features/flight_deck/favorites_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a set through a comma-joined string', () {
    expect(decodeFavorites(encodeFavorites({'a', 'b'})), {'a', 'b'});
    expect(decodeFavorites(null), isEmpty);
    expect(decodeFavorites(''), isEmpty);
    expect(encodeFavorites({}), '');
  });
}
