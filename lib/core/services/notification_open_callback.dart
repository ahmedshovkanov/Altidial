import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_config.dart';

/// Tells the backend that the app was opened from a push notification:
/// `PUT interaction.php?message_id=...` with the AppsFlyer id, on the same
/// host as `config.php`.
///
/// Best effort: one attempt, the response is ignored, and nothing here throws.
class NotificationOpenCallback {
  NotificationOpenCallback._();

  /// What the backend accepts as a message id: Latin letters, digits, `_` and
  /// `-`, up to 128 characters.
  static final RegExp _messageIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  static const Duration _timeout = Duration(seconds: 30);

  /// The AppsFlyer id the config request was made with: the `af_id` saved in
  /// the conversion data, or null when there is none.
  static String? afIdOf(Object? conversionData) {
    if (conversionData is! Map) return null;
    final afId = conversionData['af_id'];
    return afId is String && afId.isNotEmpty ? afId : null;
  }

  /// The hook for `PushRouter.onNotificationOpened`: sends the callback for a
  /// tapped notification without waiting for it. [conversionData] is read when
  /// the tap happens, not before: the AppsFlyer id is saved by the config
  /// request, which may not have run yet when the hook is wired up.
  static void Function(String messageId) reporter({
    required Object? Function() conversionData,
  }) {
    return (messageId) => unawaited(
          send(messageId: messageId, afId: afIdOf(conversionData())),
        );
  }

  /// Sends the callback for [messageId], the `message_id` from the push's
  /// `data`. Nothing is sent when [messageId] or [afId] is something the
  /// backend would reject.
  static Future<void> send({
    required String? messageId,
    required String? afId,
  }) async {
    if (messageId == null || !_messageIdPattern.hasMatch(messageId)) {
      _log('skipped, bad message_id: $messageId');
      return;
    }
    if (afId == null || afId.isEmpty) {
      _log('skipped, no af_id');
      return;
    }

    final client = http.Client();
    try {
      final response = await client
          .put(
            Uri.parse('${AppConfig.endpoint}/interaction.php')
                .replace(queryParameters: {'message_id': messageId}),
            headers: const {'content-type': 'application/json'},
            body: utf8.encode(json.encode({'af_id': afId})),
          )
          .timeout(_timeout);
      _log('HTTP ${response.statusCode}');
    } catch (e) {
      _log('failed: $e');
    } finally {
      client.close();
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('Notification open callback: $message');
  }
}
