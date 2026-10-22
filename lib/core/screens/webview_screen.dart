import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sdk_initializer.dart';
import '../services/push_router.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;

  const WebViewScreen({super.key, this.initialUrl = 'https://flutter.dev'});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class UrlLauncherService {
  static Future<void> launchInBrowser({required String url}) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {}
  }
}

Future<void> _launchURL(String url) async {
  UrlLauncherService.launchInBrowser(url: url);
}

class NativeMethodCaller {
  static const MethodChannel _channel = MethodChannel(
    'com.yourapp/native_methods',
  );

  static Future<void> callSwiftMethodWithParams(
    Map<String, dynamic> params,
  ) async {
    try {
      await _channel.invokeMethod('callSwiftMethodWithParams', params);
    } on PlatformException catch (e) {}
  }
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final PlatformWebViewController controller;

  StreamSubscription<String>? _pushSub;

  bool isLoading = true;
  String currentUrl = '';

  String _targetUrl = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    final pushUrl = PushRouter.instance.takePendingUrl();
    _targetUrl = pushUrl ?? SdkInitializer.receivedUrl ?? widget.initialUrl;

    _pushSub = PushRouter.instance.urlStream.listen(_navigate);

    controller =
        WebKitWebViewController(
            WebKitWebViewControllerCreationParams(
              mediaTypesRequiringUserAction: const {},
              allowsInlineMediaPlayback: true,
            ),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..enableZoom(false)
          ..setPlatformNavigationDelegate(
            WebKitNavigationDelegate(
                const PlatformNavigationDelegateCreationParams(),
              )
              ..setOnPageStarted((String url) {
                if (!mounted) return;
                setState(() {
                  isLoading = true;
                  currentUrl = url;
                });
              })
              ..setOnPageFinished((String url) async {
                await controller.runJavaScript('''
    var originalWindowOpen = window.open;
    window.open = function(url, target, features) {
      window.location.href = url;
      return null;
    };
    document.addEventListener('click', function(e) {
      var target = e.target;
      while (target && target.nodeName !== 'A') {
        target = target.parentElement;
      }
      if (target && target.target === '_blank') {
        e.preventDefault();
        window.location.href = target.href;
      }
    });
  ''');
                if (!mounted) return;
                setState(() {
                  isLoading = false;
                  currentUrl = url;
                });
              })
              ..setOnHttpError((HttpResponseError error) {})
              ..setOnWebResourceError((WebResourceError error) {
                final url = error.url;
                if (url == null) return;
                if (error.errorCode == -1007 ||
                    error.errorCode == -9 ||
                    error.errorCode == 0) {
                  _targetUrl = url;
                  _load(url);
                }
              })
              ..setOnUrlChange((UrlChange change) {
                if (change.url == null) return;
                if (change.url!.contains("http://")) return;
                if (change.url!.contains("https://")) return;
                _launchURL(change.url!);
              }),
          )
          ..setOnPlatformPermissionRequest((
            PlatformWebViewPermissionRequest request,
          ) {
            request.grant();
          })
          ..setAllowsBackForwardNavigationGestures(true)
          ..getUserAgent().then((String? userAgent) {
            controller.setUserAgent(userAgent?.replaceAll("; wv", ""));
            _ready = true;
            _load(_targetUrl);
          });
  }

  void _load(String url) {
    controller.loadRequest(LoadRequestParams(uri: Uri.parse(url)));
  }

  void _navigate(String url) {
    if (url.isEmpty) return;

    _targetUrl = url;
    PushRouter.instance.takePendingUrl();

    if (!mounted || !_ready) return;

    _load(url);
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _pushSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      child: SafeArea(
        maintainBottomViewPadding: true,
        child: PlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams(controller: controller),
        ).build(context),
      ),
    );
  }
}