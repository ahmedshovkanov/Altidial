import 'package:energy_clock/data/repositories/export_repository.dart';

/// In-memory [ShareService]: records what would have been shared.
class FakeShareService implements ShareService {
  /// Every path passed to [shareFile], in order.
  final List<String> sharedPaths = [];

  /// Makes every share throw, as a dismissed sheet with an error would.
  bool fail = false;

  @override
  Future<void> shareFile(String path, {String? subject}) async {
    if (fail) throw StateError('sharing failed');
    sharedPaths.add(path);
  }
}
