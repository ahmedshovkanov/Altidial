import 'dart:async';
import 'dart:io' show Platform;
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../firebase_options.dart';
import '../app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_messaging_service.dart';
import '../screens/no_internet_connection.dart';
import 'push_request_control.dart';
import '../screens/push_request_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/webview_screen.dart';

class SdkInitializer {
  static BuildContext? _context;
  static AppsflyerSdk? _appsflyerSdk;

  // Хранилище для переменных во время выполнения приложения
  static final Map<String, dynamic> _runtimeStorage = {};
  static Map<String, dynamic> _convrtsion = {};

  // Геттеры для удобного доступа к часто используемым переменным
  static String? receivedUrl;
  static String? get conversionData =>
      _runtimeStorage['conversionData'] as String?;
  static Map<String, dynamic>? get serverResponse =>
      _runtimeStorage['serverResponse'] as Map<String, dynamic>?;
  static String? get apnsToken => _runtimeStorage['apnsToken'] as String?;
  static SharedPreferences? prefs;

  static PushRequestData? pushRequestData;

  static String deep_link_sub1 = "";
  static String deep_link_value = "";

  /// Сохраняет содержимое _runtimeStorage в строку JSON
  static String saveRuntimeStorage() {
    try {
      return json.encode(_runtimeStorage);
    } catch (e) {
      return '{}';
    }
  }

  /// Загружает содержимое JSON-строки в _runtimeStorage (старые значения перезаписываются)
  static void loadRuntimeStorage(String jsonString) {
    try {
      Map<String, dynamic> map = json.decode(jsonString);
      _runtimeStorage
        ..clear()
        ..addAll(map);
    } catch (e) {}
  }

  // Методы для работы с хранилищем
  static void setValue(String key, dynamic value) {
    _runtimeStorage[key] = value;
    saveRuntimeStorageToDevice();
  }

  static Future<void> saveRuntimeStorageToDevice() async {
    try {
      final jsonString = saveRuntimeStorage();
      await prefs!.setString('runtimeStorage', jsonString);
    } catch (e) {
      if (AppConfig.isDebug) {
        print('Ошибка при сохранении runtimeStorage на девайсе: $e');
      }
    }
  }

  static Future<void> loadRuntimeStorageToDevice() async {
    try {
      var json = await prefs!.getString('runtimeStorage');
      loadRuntimeStorage(json!);
      if (AppConfig.isDebug) {
        print('runtimeStorage успешно загружен');
      }
    } catch (e) {
      if (AppConfig.isDebug) {
        print('Ошибка при сохранении runtimeStorage на девайсе: $e');
      }
    }
  }

  static dynamic getValue(String key) {
    return _runtimeStorage[key];
  }

  static bool hasValue(String key) {
    return _runtimeStorage.containsKey(key);
  }

  static void clearStorage() {
    _runtimeStorage.clear();
  }

  static Map<String, dynamic> getAllValues() {
    return Map.from(_runtimeStorage);
  }

  static void showApp(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => AppConfig.appContent),
      (route) => false,
    );
  }

  static void showWeb(BuildContext context) {
    if (AppConfig.isDebug) {
      print('3 showWeb');
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WebViewScreen()),
      (route) => false,
    );
  }

  static const MethodChannel _channel = MethodChannel(
    'com.yourapp/native_methods',
  );

  static Future<void> callSwiftMethod() async {
    try {
      await _channel.invokeMethod('callSwiftMethod');
    } on PlatformException catch (e) {
      if (AppConfig.isDebug) {
        print("Failed to call Swift method: '${e.message}'");
      }
    }
  }

  static Future<void> initAll(BuildContext context) async {
    var isNotInternet =
        await NoInternetConnectionScreen.checkInternetConnection();

    if (!isNotInternet) {
      NoInternetConnectionScreen.showIfNoInternet(context);
      return;
    }
    prefs = await SharedPreferences.getInstance();
    await loadRuntimeStorageToDevice();

    if (hasValue("pushRequestData")) {
      pushRequestData = PushRequestData.fromJson(getValue("pushRequestData"));
    } else {
      pushRequestData = PushRequestData();
    }
    _context = context;

    var isFirstStart = !hasValue("isFirstStart");
    if (!isFirstStart) {
      var isOrganic = getValue("Organic");
      if (!isOrganic) {
        Map<String, dynamic> conversion = getValue("conversionData");
        if (AppConfig.isDebug) {
          print(conversion);
        }
        receivedUrl = await makeConversion(conversion);
        if (PushRequestControl.shouldShowPushRequest(pushRequestData!)) {
          Navigator.pushAndRemoveUntil(
            _context!,
            MaterialPageRoute(builder: (context) => const PushRequestScreen()),
            (route) => false,
          );
        } else {
          showWeb(context);
        }
      } else {
        showApp(context);
      }
      return;
    }
  }

  static Future<String> makeConversion(
    Map<String, dynamic> conversionMap, {
    String? apnsToken,
    bool isLoad = true,
  }) async {
    conversionMap.addEntries([
      MapEntry("store_id", "id" + AppConfig.appsFlyerAppId),
      MapEntry("bundle_id", AppConfig.bundleId),
      MapEntry("locale", AppConfig.locale),
      MapEntry("os", AppConfig.os),
      MapEntry("firebase_project_id", DefaultFirebaseOptions.ios.projectId),
    ]);

    if (apnsToken != null) {
      conversionMap.addEntries([MapEntry("push_token", apnsToken)]);
    }
    var result = await sendPostRequest(
      body: conversionMap,
      url: AppConfig.endpoint + "/config.php",
    );

    if (result == null || !result.containsKey("url")) {
      // if (getValue("Organic")) return "";
      if (hasValue('urls')) {
        print("return local url");
        return await getValue('urls');
      }
      print("return \'\'");
      return '';
    }

    setValue('serverResponse', result);
    setValue("urls", result['url']);
    return result['url'];
  }

  static void onEndRequest(String? url) {
    if (url == null || url == "") {
      if (AppConfig.isDebug) {
        print('not url');
      }
      setValue("Organic", true);
      setValue("isFirstStart", true);

      showApp(_context!);

      return;
    }
    setValue("Organic", false);
    setValue("isFirstStart", true);

    setValue('serverResponse', url);

    receivedUrl = url;
    setValue('urlReceivedAt', DateTime.now().toIso8601String());
    if (AppConfig.isDebug) {
      print('url');
    }

    if (PushRequestControl.shouldShowPushRequest(pushRequestData!)) {
      if (AppConfig.isDebug) {
        print('url1');
      }
      Navigator.pushAndRemoveUntil(
        _context!,
        MaterialPageRoute(builder: (context) => const PushRequestScreen()),
        (route) => false,
      );
    } else {
      if (AppConfig.isDebug) {
        print('url2');
      }
      Navigator.push(
        _context!,
        MaterialPageRoute(builder: (context) => const WebViewScreen()),
      );
    }
  }

  static bool isHasConversion = false;
  static void initAppsFlyer() {
    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: AppConfig.appsFlyerDevKey,
      appId: AppConfig.appsFlyerAppId,
      showDebug: false,
      timeToWaitForATTUserAuthorization: 9,
      manualStart: true,
    );
    _appsflyerSdk = AppsflyerSdk(options);
    if (AppConfig.isDebug) {
      print('add af');
    }
    _appsflyerSdk!.onAppOpenAttribution((res) {
      if (AppConfig.isDebug) {
        print("onAppOpenAttribution res: $res");
      }
    });
    _appsflyerSdk!.setOneLinkCustomDomain(['']);
    _appsflyerSdk!.onDeepLinking((DeepLinkResult dp) {
      switch (dp.status) {
        case Status.FOUND:
          if (AppConfig.isDebug) {
            print(dp.deepLink?.toString());
          }
          if (AppConfig.isDebug) {
            print("onDeepLinking res: $dp");
          }

          var map = dp.deepLink!.clickEvent;
          _convrtsion.addAll(map);
          if (AppConfig.isDebug) {
            print(
              'deep_link_value=$deep_link_value deep_link_sub1=$deep_link_sub1|',
            );
          }
          break;
        case Status.NOT_FOUND:
          if (AppConfig.isDebug) {
            print("deep link not found");
          }
          break;
        case Status.ERROR:
          if (AppConfig.isDebug) {
            print("deep link error: ${dp.error}");
          }
          break;
        case Status.PARSE_ERROR:
          if (AppConfig.isDebug) {
            print("deep link status parsing error");
          }
          break;
      }
      if (AppConfig.isDebug) {
        print("onDeepLinking res: $dp");
      }
    });

    _appsflyerSdk
        ?.initSdk(
          registerConversionDataCallback: true,
          registerOnAppOpenAttributionCallback: true,
          registerOnDeepLinkingCallback: true,
        )
        .then((value) {
          if (AppConfig.isDebug) {
            print('_appsflyerSdk initSdk');
          }

          _appsflyerSdk?.onInstallConversionData((res) {
            if (isHasConversion) return;
            isHasConversion = true;
            _appsflyerSdk?.getAppsFlyerUID().then((value) async {
              if (value == null) return;
              Map<String, dynamic> conversionMap = res["payload"];

              if (AppConfig.isDebug) {
                print("start load conversion 1");
              }
              if (AppConfig.isDebug) {
                print("af_sub2: ${conversionMap['af_sub1']}");
              }

              if (AppConfig.isDebug) {
                print(_convrtsion);
              }
              if (AppConfig.isDebug) {
                print("start load conversion 2");
              }

              if (AppConfig.isDebug) {
                print(conversionMap);
              }

              if (AppConfig.isDebug) {
                print("start load conversion 3");
              }

              for (var entry in conversionMap.entries) {
                if (entry.value != '') {
                  _convrtsion[entry.key] = entry.value;

                  if (AppConfig.isDebug) {
                    print(
                      '|${entry.key} - ${entry.value} |${_convrtsion[entry.key]}',
                    );
                  }
                }
              }

              if (_convrtsion != null) {
                _convrtsion.addEntries([MapEntry("af_id", value)]);

                setValue('conversionData', _convrtsion);
                var url = await makeConversion(_convrtsion);
                if (AppConfig.isDebug) {
                  print("url -" + url);
                }
                onEndRequest(url);
              }
            });
          });
          _appsflyerSdk?.startSDK(
            onSuccess: () {
              if (AppConfig.isDebug) {
                print("AppsFlyer SDK initialized successfully.");
              }
            },
            onError: (int errorCode, String errorMessage) {
              if (AppConfig.isDebug) {
                print(options.afDevKey + " " + options.appId);
              }
              if (AppConfig.isDebug) {
                print(
                  "Error initializing AppsFlyer SDK: Code $errorCode - $errorMessage",
                );
              }
            },
          );
        });
  }

  /// Запрашивает APNS токен через FirebaseMessaging
  static Future<String?> requestAPNSToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();

      var token = await FirebaseMessaging.instance.getAPNSToken();
      if (AppConfig.isDebug) {
        print("first token");
      }
      if (AppConfig.isDebug) {
        print(token);
      }
      if (AppConfig.isDebug) {
        print(DefaultFirebaseOptions.currentPlatform.projectId);
      }
      String? apnsToken;
      int retries = 10;
      for (int i = 0; i < retries; i++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          if (AppConfig.isDebug) {
            print('APNS токен получен: $apnsToken');
          }
          return apnsToken;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (AppConfig.isDebug) {
        print('APNS токен не получен (timeout)');
      }
      return null;
    } catch (e) {
      if (AppConfig.isDebug) {
        print('Ошибка при ��олучении APNS токена: $e');
      }
      return null;
    }
  }

  static bool isIOSSimulator() {
    return false;
    if (!Platform.isIOS) return false;

    return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
        Platform.environment.containsKey('SIMULATOR_HOST_HOME') ||
        Platform.environment.containsKey('SIMULATOR_UDID');
  }

  static Future<void> pushRequest(BuildContext context) async {
    await Firebase.initializeApp();

    var token = await FirebaseMessagingService.InitPushAndGetToken();
    if (token == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WebViewScreen()),
        (route) => false,
      );
      return;
    }

    PushRequestControl.acceptPushRequest(pushRequestData!);

    setValue("pushRequestData", pushRequestData?.toJson());
    _convrtsion = SdkInitializer.getValue('conversionData');
    if (_convrtsion is Map<String, dynamic>) {
      if (AppConfig.isDebug) {
        print("makeConversion 2");
      }
      var url = await SdkInitializer.secondMakeConversion(
        _convrtsion,
        apnsToken: token,
        isLoad: false,
      );
      setValue(url, "receivedUrl");
      if (AppConfig.isDebug) {
        print("pushRequest ");
      }
      _runtimeStorage['receivedUrl'] = url;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WebViewScreen()),
        (route) => false,
      );
    }
  }

  static Future<String> secondMakeConversion(
    Map<String, dynamic> conversionMap, {
    String? apnsToken,
    bool isLoad = true,
  }) async {
    conversionMap.addEntries([MapEntry("push_token", apnsToken)]);

    if (AppConfig.isDebug) {
      print(conversionMap["firebase_project_id"]);
    }

    if (AppConfig.isDebug) {
      print("with token " + conversionMap.toString());
    }
    setValue("", conversionMap);
    var result = await sendPostRequest(
      body: conversionMap,
      url: AppConfig.endpoint + "/config.php",
    );

    if (result == null) return "";
    setValue('serverResponse', result);
    if (!result.containsKey("url")) return "";
    return result['url'];
  }

  static void pushRequestDecline() {
    PushRequestControl.declinePushRequest(pushRequestData!);
    setValue("pushRequestData", pushRequestData?.toJson());
  }
}

Map<String, dynamic> parseJsonFromString(String jsonString) {
  if (AppConfig.isDebug) {
    print("1 " + jsonString);
  }
  String cleanedString = jsonString.trim();
  if (AppConfig.isDebug) {
    print("2 " + cleanedString);
  }
  Map<String, dynamic> jsonMap = jsonDecode(cleanedString);

  return jsonMap;
}

String mapToJsonString(Map<String, dynamic> map) {
  try {
    String jsonString = json.encode(map);
    return jsonString;
  } catch (e) {
    if (AppConfig.isDebug) {
      print('Ошибка преобразования в JSON: $e');
    }
    return '{}';
  }
}

Future<Map<String, dynamic>?> sendPostRequest({
  required String url,
  required Map<String, dynamic> body,
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 30),
}) async {
  if (AppConfig.isDebug) {
    print(body);
  }
  try {
    Map<String, String> requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    http.Response response = await http
        .post(Uri.parse(url), headers: requestHeaders, body: json.encode(body))
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      Map<String, dynamic> result = json.decode(response.body);
      return result;
    } else {
      if (AppConfig.isDebug) {
        print('HTTP Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    }
  } catch (e) {
    if (AppConfig.isDebug) {
      print('Ошибка запроса: $e');
    }
    return null;
  }
}

class EventBus {
  final _controller = StreamController<dynamic>.broadcast();

  static final EventBus instance = EventBus();

  Stream<dynamic> get events => _controller.stream;

  void fire(dynamic event) {
    print(event);
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}