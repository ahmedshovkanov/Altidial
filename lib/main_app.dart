import 'package:altidial/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry point for the Altidial app.
///
/// Used as [AppConfig.appContent] and shown when the SDK layer decides the
/// user is organic (or after the web-view flow). The target app keeps its own
/// async bootstrap — the Riverpod scope and the onboarding/settings providers
/// load inside [AltidialApp] — so it can be instantiated as
/// `const AltidialMainApp()`.
class AltidialMainApp extends StatefulWidget {
  const AltidialMainApp({super.key});

  @override
  State<AltidialMainApp> createState() => _AltidialMainAppState();
}

class _AltidialMainAppState extends State<AltidialMainApp> {
  @override
  void initState() {
    super.initState();
    // Nunito is licensed under the SIL Open Font Licence; list it on the
    // licences page.
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/OFL.txt');
      yield LicenseEntryWithLineBreaks(<String>['Nunito'], text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: AltidialApp());
  }
}
