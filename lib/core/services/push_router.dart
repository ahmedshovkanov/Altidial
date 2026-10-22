import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PushRouter with WidgetsBindingObserver {
  PushRouter._();

  static final PushRouter instance = PushRouter._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.yourapp/push_taps');

  final StreamController<String> _urls = StreamController<String>.broadcast();
  final Set<String> _handledIds = <String>{};

  StreamSubscription<RemoteMessage>? _openedAppSub;

  bool _observerAdded = false;
  bool _pollStarted = false;
  int _lastSeq = 0;
  String? _pendingUrl;

  final Set<String> _reportedMessageIds = <String>{};

  /// Called with the backend's `message_id` of a notification the user tapped,
  /// once per id. `main.dart` points it at the notification-open callback; it
  /// is a hook so the router needs nothing from the SDK layer.
  void Function(String messageId)? onNotificationOpened;

  Stream<String> get urlStream => _urls.stream;

  bool get hasPendingUrl => _pendingUrl != null;

  Future<void> init() async {
    if (!_observerAdded) {
      _observerAdded = true;
      WidgetsBinding.instance.addObserver(this);
    }

    _openedAppSub ??=
        FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage);

    await _pullNativeTaps();

    if (!_pollStarted) {
      _pollStarted = true;
      // ignore: unawaited_futures
      _pollInitialMessage();
    }
  }

  Future<void> reclaimNotificationDelegate() async {
    try {
      await _nativeChannel.invokeMethod('reclaimNotificationDelegate');
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      _pullNativeTapsWithRetries();
    }
  }

  Future<void> _pullNativeTapsWithRetries() async {
    await _pullNativeTaps();
    await Future.delayed(const Duration(milliseconds: 300));
    await _pullNativeTaps();
    await Future.delayed(const Duration(milliseconds: 600));
    await _pullNativeTaps();
  }

  Future<void> _pullNativeTaps() async {
    try {
      final raw = await _nativeChannel
          .invokeMethod<List<dynamic>>('takeNotificationTaps');
      if (raw == null || raw.isEmpty) return;

      final taps = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        ..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));

      for (final tap in taps) {
        _apply(
          seq: tap['seq'] as int?,
          id: (tap['messageId'] as String?) ?? '',
          url: (tap['url'] as String?) ?? '',
        );
        _reportOpen(tap['dataMessageId']);
      }
    } catch (_) {}
  }

  void _handleFcmMessage(RemoteMessage message) {
    _apply(
      seq: null,
      id: message.messageId ?? '${message.data}',
      url: (message.data['url'] as String?) ?? '',
    );
    _reportOpen(message.data['message_id']);
  }

  Future<void> _pollInitialMessage() async {
    for (var i = 0; i < 12; i++) {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        _apply(
          seq: null,
          id: message.messageId ?? '${message.data}',
          url: (message.data['url'] as String?) ?? '',
        );
        _reportOpen(message.data['message_id']);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  void _apply({
    required int? seq,
    required String id,
    required String url,
  }) {
    if (url.isEmpty) return;

    if (id.isNotEmpty && !_handledIds.add(id)) return;

    if (seq != null) {
      if (seq <= _lastSeq) return;
      _lastSeq = seq;
    }

    _pendingUrl = url;
    _urls.add(url);
  }

  /// Reports a tapped notification to [onNotificationOpened], once per
  /// [messageId]. Kept apart from [_apply]: it never changes what a tap opens,
  /// and a failing hook cannot stop a tap from opening it.
  void _reportOpen(Object? messageId) {
    final id = messageId?.toString() ?? '';
    final report = onNotificationOpened;
    if (id.isEmpty || report == null || !_reportedMessageIds.add(id)) return;
    try {
      report(id);
    } catch (_) {}
  }

  /// The payload for the local notification the app shows for a push that
  /// arrived in the foreground: the push's `data` as JSON, which
  /// [handleLocalNotificationTap] reads back. Falls back to the plain map text
  /// the payload used to be if the data cannot be encoded.
  static String encodeLocalPayload(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  /// A tap on a notification the app showed itself, with the payload
  /// [encodeLocalPayload] made. Only reports the open: unlike a tap on the push
  /// itself it opens no url.
  void handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) _reportOpen(data['message_id']);
    } catch (_) {}
  }

  String? takePendingUrl() {
    final url = _pendingUrl;
    _pendingUrl = null;
    return url;
  }

  Future<void> dispose() async {
    if (_observerAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAdded = false;
    }
    await _openedAppSub?.cancel();
    _openedAppSub = null;
    await _urls.close();
  }
}