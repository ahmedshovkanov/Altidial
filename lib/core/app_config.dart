import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

import '../main_app.dart';

/// Application configuration
/// Contains all app settings, SDK credentials, and UI customization
class AppConfig {
  // Dark-palette values mirrored from app/theme/app_colors.dart and
  // tone_colors.dart, kept as literals so this file stays const-constructible.
  static const Color _page = Color(0xFF0F0F14);
  static const Color _surface = Color(0xFF1A1A22);
  static const Color _ink = Color(0xFFF4F4F8);
  static const Color _muted = Color(0xFFA7A5B5);
  static const Color _focus = Color(0xFF8E78FF);

  // ============================================================================
  // SDK Configuration
  // ============================================================================

  /// AppsFlyer developer key
  static const String appsFlyerDevKey = 'BeDZa9cB5AEkYstTP9q3iD';

  /// AppsFlyer App ID (iOS App Store ID)
  static const String appsFlyerAppId = '6825730133';

  /// Application bundle identifier
  static const String bundleId = 'com.nolanbouchet.altdial';

  /// Application locale
  static const String locale = 'en';

  /// Platform OS
  static const String os = 'iOS';

  /// Backend server endpoint
  static const String endpoint = 'https://altidiial.com';

  /// Debug-logging switch used by core services
  static const bool isDebug = kDebugMode;

  // ============================================================================
  // Application Content
  // ============================================================================

  /// Main app content widget (shown for organic users)
  static const Widget appContent = AltidialMainApp();

  // ============================================================================
  // WebGL Configuration
  // ============================================================================

  /// WebGL game endpoint URL
  static const String webGLEndpoint = '';

  /// Allowed device orientations for WebGL
  static const List<DeviceOrientation> webGLAllowedOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  // ============================================================================
  // UI Customization - Shared gradient background
  // ============================================================================

  /// Shared background gradient used across all core screens: the app's own
  /// page and surface tones, so the splash, the push request and the
  /// no-internet screen all open on Altidial's colours.
  static const List<Color> backgroundGradientColors = [_page, _surface];

  static const Gradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: backgroundGradientColors,
  );

  // ============================================================================
  // UI Customization - Splash Screen
  // ============================================================================

  /// Splash screen background decoration
  static const Decoration splashDecoration = BoxDecoration(
    gradient: screenGradient,
  );

  /// Splash screen loading text color
  static const Color splashLoadingTextColor = _ink;

  /// Splash screen spinner color: the Focus tone, the app's primary accent
  static const Color splashSpinnerColor = _focus;

  // ============================================================================
  // UI Customization - Push Request Screen
  // ============================================================================

  /// Push request screen background decoration
  static const Decoration pushRequestDecoration = BoxDecoration(
    gradient: screenGradient,
  );

  /// Push request screen fade gradient overlay
  static const Gradient pushRequestFadeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), _page],
  );

  /// Push request bottom fade into the screen background
  static const Gradient pushRequestTextFadeGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [_page, Color(0x00000000)],
  );

  /// Push request title text color
  static const Color pushRequestTitleColor = _ink;

  /// Push request "Skip" text color
  static const Color pushRequestSkipTextColor = _muted;

  // ============================================================================
  // UI Customization - Error Screen
  // ============================================================================

  /// Error screen background decoration
  static const Decoration errorScreenDecoration = BoxDecoration(
    gradient: screenGradient,
  );

  /// Error screen text color
  static const Color errorScreenTextColor = _ink;

  /// Error screen icon color
  static const Color errorScreenIconColor = _ink;

  // ============================================================================
  // UI Customization - WebGL Loading Screen
  // ============================================================================

  /// WebGL loading screen background decoration
  static const Decoration webGLLoadingDecoration = BoxDecoration(
    gradient: screenGradient,
  );

  /// WebGL loading screen text
  static const String webGLLoadingText = 'Initialization...';

  /// WebGL loading spinner color
  static const Color webGLSpinnerColor = _ink;

  /// WebGL loading text color
  static const Color webGLLoadingTextColor = _ink;
}
