import 'dart:ui';

/// The HopAndPost palette, named by role rather than by hue.
///
/// Three families, three distinct jobs. Keeping them distinct is what
/// keeps the app on one design:
///
/// * `surface*` is the **ground** — a five-step value ladder. Elevation is
///   expressed by moving up this ladder, never by changing hue.
/// * `brand*` is a **fill** — buttons and warm emphasis. Never a page
///   ground.
/// * `accent*` is **reserved**. It may appear only on something special or
///   currently active; everything ambient uses [edge]. The token names are
///   the enforcement: choosing `edge` over `accent` is a semantic decision,
///   not a colour preference.
///
/// Contrast for every pair the app actually renders is asserted in
/// `test/core/theme/palette_contrast_test.dart`. Editing a value here
/// without running that test is how a palette rots.
abstract final class AppColors {
  // --- Ground ---------------------------------------------------------
  static const Color surfaceVoid = Color(0xFF060A13);
  static const Color surfaceBase = Color(0xFF0B101E);
  static const Color surfaceRaised = Color(0xFF121A2B);
  static const Color surfacePanel = Color(0xFF1D263A);

  /// Default rim and divider. The ambient counterpart to [accent].
  static const Color edge = Color(0xFF303C55);

  // --- Brand ----------------------------------------------------------
  static const Color brandDeep = Color(0xFF081A11);
  static const Color brand = Color(0xFF0C2A1B);
  static const Color brandLift = Color(0xFF256B44);

  // --- Accent (reserved) ----------------------------------------------
  static const Color accentDeep = Color(0xFF7C561D);
  static const Color accent = Color(0xFFE1A937);
  static const Color accentLight = Color(0xFFF6D584);

  // --- Text -----------------------------------------------------------
  static const Color textPrimary = Color(0xFFF2EFE9);

  /// Secondary text. A real colour rather than an alpha of [textPrimary],
  /// so it stays legible on every rung of the surface ladder instead of
  /// changing contrast with whatever happens to be behind it.
  static const Color textMuted = Color(0xFFBDB5A8);

  // --- Semantic -------------------------------------------------------
  // Fills carry shapes; the `*Text` variants are the legible-on-dark
  // counterparts for labels. Event deliberately has no pair of its own:
  // an event *is* the special case, so it reuses the accent family.
  static const Color safe = Color(0xFF33A37A);
  static const Color safeText = Color(0xFF61D1A8);
  static const Color risk = Color(0xFFDE4C35);
  static const Color riskText = Color(0xFFEF826C);
  static const Color route = Color(0xFF4076B5);
  static const Color routeText = Color(0xFF7BAAE0);

  /// The delivery node's family: carries one of the run's mail targets.
  static const Color delivery = Color(0xFF8C4FBF);
  static const Color deliveryText = Color(0xFFD79EE8);

  /// The dice-cache node's family: grants bonus dice on arrival.
  static const Color diceCache = Color(0xFF2E9E8C);
  static const Color diceCacheText = Color(0xFF8FE0D1);

  /// Scrim behind every overlay: [surfaceVoid] at 78%.
  static const Color scrim = Color(0xC7060A13);

  // --- Avatar colourways ----------------------------------------------
  // Six body tints at matched lightness so they read as one family. All
  // clear 4.5:1 against [surfaceBase] — asserted in the contrast test.
  static const Color avatarClassic = textPrimary;
  static const Color avatarEmber = Color(0xFFE38963);
  static const Color avatarDusk = Color(0xFFAB89D1);
  static const Color avatarFrost = Color(0xFF8CC4D9);
  static const Color avatarGilded = accentLight;
  static const Color avatarAsh = Color(0xFF98A0AE);

}
