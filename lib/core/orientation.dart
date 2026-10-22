import 'package:flutter/services.dart';

/// Portrait-only — used where a screen must stay upright.
const List<DeviceOrientation> kSupportedOrientations = [
  DeviceOrientation.portraitUp,
];

/// All orientations — used to release the portrait lock.
const List<DeviceOrientation> kAllOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

Future<void> lockOrientation() =>
    SystemChrome.setPreferredOrientations(kSupportedOrientations);

Future<void> unlockOrientation() =>
    SystemChrome.setPreferredOrientations(kAllOrientations);
