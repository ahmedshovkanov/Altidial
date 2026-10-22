import 'package:energy_clock/core/flight/flight_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes and validates IATA codes', () {
    expect(normalizeAirportCode(' sof '), 'SOF');
    expect(isValidAirportCode('SOF'), isTrue);
    expect(isValidAirportCode('SO'), isFalse);
    expect(isValidAirportCode('SOF1'), isFalse);
    expect(isValidAirportCode('so f'), isFalse);
  });

  test('flight number is optional but constrained when present', () {
    expect(normalizeFlightNumber(' lh 715 '), 'LH715');
    expect(isValidFlightNumber(''), isTrue);
    expect(isValidFlightNumber('LH715'), isTrue);
    expect(isValidFlightNumber('LH-715'), isFalse);
    expect(isValidFlightNumber('ABCDEFGHI'), isFalse);
  });

  test('subtitle prefers number and route', () {
    expect(
      flightSubtitle(flightNumber: 'LH715', fromCode: 'SOF', toCode: 'BER'),
      'LH715 · SOF→BER',
    );
    expect(
      flightSubtitle(flightNumber: null, fromCode: 'SOF', toCode: 'BER'),
      'SOF→BER',
    );
  });
}
