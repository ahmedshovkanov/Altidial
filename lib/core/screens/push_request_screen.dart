import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sdk_initializer.dart';
import 'push_request_view.dart';
import 'webview_screen.dart';

class PushRequestScreen extends StatefulWidget {
  const PushRequestScreen({Key? key}) : super(key: key);

  @override
  State<PushRequestScreen> createState() => _PushRequestScreenState();
}

class _PushRequestScreenState extends State<PushRequestScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PushRequestView(
        onAllow: () {
          SdkInitializer.pushRequest(context);
        },
        onSkip: () {
          SdkInitializer.pushRequestDecline();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}
