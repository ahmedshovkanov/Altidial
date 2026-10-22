/// What the app needs from local notifications. The plugin behind it is an
/// implementation detail, so features and tests depend only on this.
abstract interface class NotificationService {
  /// Whether the system will show this app's notifications right now.
  Future<bool> areEnabled();

  /// Shows the system permission prompt and returns whether it was granted.
  /// iOS shows the prompt once; after a refusal this returns false at once.
  Future<bool> requestPermission();

  /// Schedules a notification for the absolute instant [at], replacing any
  /// pending one with the same [id].
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Removes the pending notification [id], if any.
  Future<void> cancel(int id);

  /// Opens the app's notification settings in the Settings app.
  Future<void> openSettings();
}
