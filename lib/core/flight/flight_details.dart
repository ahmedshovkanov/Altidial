/// Pure flight-field helpers. No Flutter, no database. IATA codes are exactly
/// three A-Z letters; flight numbers are optional, 2-8 chars of A-Z/0-9.
String normalizeAirportCode(String input) => input.trim().toUpperCase();

bool isValidAirportCode(String input) =>
    RegExp(r'^[A-Z]{3}$').hasMatch(normalizeAirportCode(input));

String normalizeFlightNumber(String input) =>
    input.trim().toUpperCase().replaceAll(' ', '');

bool isValidFlightNumber(String input) {
  if (input.trim().isEmpty) return true;
  return RegExp(r'^[A-Z0-9]{2,8}$').hasMatch(normalizeFlightNumber(input));
}

String flightSubtitle({
  String? flightNumber,
  String? fromCode,
  String? toCode,
}) {
  final route = (fromCode == null || toCode == null) ? '' : '$fromCode→$toCode';
  final number = (flightNumber == null || flightNumber.isEmpty)
      ? ''
      : flightNumber;
  if (number.isNotEmpty && route.isNotEmpty) return '$number · $route';
  if (route.isNotEmpty) return route;
  return number;
}
