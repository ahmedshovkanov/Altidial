/// Indirection for the app's two font families.
///
/// The pairing is deliberate. Jersey10 is a single-weight pixel face: it
/// carries the game's identity at display sizes, but at label and body
/// sizes its small x-height forced the old scale to inflate everything to
/// 22pt to stay readable. Inter takes the small sizes and brings real
/// weights plus tabular figures.
abstract final class AppFonts {
  /// Titles, display numbers, and identity moments.
  static const String displayFamily = 'Jersey10';

  /// Body copy, labels, captions, and every rendered number.
  static const String bodyFamily = 'Inter';
}
