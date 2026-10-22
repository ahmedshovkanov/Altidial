import 'package:flutter/widgets.dart';

/// How much room the app window has. Layout follows the window width, not the
/// device name, because iPad windows resize in Split View, Slide Over, and
/// iPadOS windowing.
enum WindowClass { narrow, medium, wide }

const double mediumWindowMinWidth = 600;
const double wideWindowMinWidth = 900;

WindowClass windowClassFor(double width) {
  if (width >= wideWindowMinWidth) return WindowClass.wide;
  if (width >= mediumWindowMinWidth) return WindowClass.medium;
  return WindowClass.narrow;
}

extension WindowClassContext on BuildContext {
  WindowClass get windowClass => windowClassFor(MediaQuery.sizeOf(this).width);
}
