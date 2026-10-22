import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the platform browser. Silently swallows failures so widget
/// tests (no platform bridge) and unsupported platforms do not crash.
Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Ignore: no browser available.
  }
}
