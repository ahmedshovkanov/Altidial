// lib/features/flight_deck/favorites_codec.dart
/// Favorites persist as one comma-joined string in the settings table (which
/// has no list API). Card ids never contain commas (see calm_content_test).
String encodeFavorites(Set<String> ids) => ids.join(',');

Set<String> decodeFavorites(String? stored) {
  if (stored == null || stored.isEmpty) return {};
  return stored.split(',').where((id) => id.isNotEmpty).toSet();
}
