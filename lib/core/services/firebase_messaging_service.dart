import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notifications_service.dart';
import 'push_router.dart';

class FirebaseMessagingService {
  FirebaseMessagingService._internal();

  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  factory FirebaseMessagingService.instance() => _instance;

  LocalNotificationsService? _localNotificationsService;

  bool _initialized = false;
  String? _token;

  Future<String> init({
    required LocalNotificationsService localNotificationsService,
  }) async {
    _localNotificationsService = localNotificationsService;

    if (_initialized) {
      await PushRouter.instance.init();
      return _token ?? await _handlePushNotificationsToken();
    }
    _initialized = true;

    var token = await _handlePushNotificationsToken();

    _requestPermission();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    await PushRouter.instance.init();

    return token;
  }

  Future<String> _handlePushNotificationsToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      print('Push notifications token: $token');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
      if (kDebugMode) {
        print('FCM token refreshed: $fcmToken');
      }
    }).onError((error) {
      if (kDebugMode) {
        print('Error refreshing FCM token: $error');
      }
    });

    _token = token!;
    return _token!;
  }

  Future<void> _requestPermission() async {
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${result.authorizationStatus}');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message received: ${message.data.toString()}');
    }
    final notificationData = message.notification;
    if (notificationData != null) {
      _localNotificationsService?.showNotification(
        notificationData.title,
        notificationData.body,
        PushRouter.encodeLocalPayload(message.data),
      );
    }
  }

  static Future<String> InitPushAndGetToken() async {
    final localNotificationsService = LocalNotificationsService.instance();
    await localNotificationsService.init();

    await PushRouter.instance.reclaimNotificationDelegate();

    final firebaseMessagingService = FirebaseMessagingService.instance();
    var token = await firebaseMessagingService.init(
      localNotificationsService: localNotificationsService,
    );

    return token;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message received: ${message.data.toString()}');
  }
}