/// The app's spacing and radius scales.
///
/// Before these existed the codebase used eleven distinct vertical gaps
/// (2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24) chosen per screen. That is the
/// measurable version of "it doesn't look like one app": nothing was
/// wrong individually, but no two screens shared a rhythm.
///
/// Six steps is enough for every layout in this app. Reach for the nearest
/// step rather than adding a new one.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. [md] is the default for controls and raised cards; [lg]
/// is reserved for overlay panels, so a panel reads as a larger object
/// than the cards inside it.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}
