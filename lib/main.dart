import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/sdk_initializer.dart';
import 'core/services/notification_open_callback.dart';
import 'core/services/push_router.dart';
import 'firebase_options.dart';
import 'package:flutter/cupertino.dart';
import 'core/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SdkInitializer.prefs = await SharedPreferences.getInstance();
  await SdkInitializer.loadRuntimeStorageToDevice();
  var isFirstStart = !SdkInitializer.hasValue("isFirstStart");
  var isOrganic = SdkInitializer.getValue("Organic");
  if (kDebugMode) {
    print('add af2 $isFirstStart $isOrganic');
  }
  if (isFirstStart) SdkInitializer.initAppsFlyer();

  // Tell the backend when the user opens the app from a notification.
  PushRouter.instance.onNotificationOpened = NotificationOpenCallback.reporter(
    conversionData: () => SdkInitializer.getValue('conversionData'),
  );
  await PushRouter.instance.init();

  runApp(
    const App(),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}