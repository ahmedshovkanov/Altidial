import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import '../app_config.dart';
import '../theme/app_space.dart';
import '../widgets/animated_gradient_background.dart';

class NoInternetConnectionScreen extends StatelessWidget {
  const NoInternetConnectionScreen({super.key});

  static Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static void showIfNoInternet(BuildContext context) async {
    if (kDebugMode) {
      print('ShowIfNoInternet');
    }
    Navigator.pushAndRemoveUntil(
      context!,
      MaterialPageRoute(
        builder: (context) => const NoInternetConnectionScreen(),
        fullscreenDialog: true,
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Centred when it fits; scrolls, rather than overflowing, on a short
    // screen or with large system text.
    return Scaffold(
      body: AnimatedGradientBackground(
        colors: AppConfig.backgroundGradientColors,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 96,
                          color: AppConfig.errorScreenIconColor,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppConfig.errorScreenTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check your connection and try again',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppConfig.errorScreenTextColor.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
