import 'package:flutter_riverpod/flutter_riverpod.dart';

class _SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int tab) => state = tab;
}

final selectedTabProvider = NotifierProvider<_SelectedTabNotifier, int>(
  _SelectedTabNotifier.new,
);

/// Incremented each time the device regains network connectivity.
/// Pages that accept this value call _load() in didUpdateWidget when it changes.
class _NetworkRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final networkRefreshTriggerProvider =
    NotifierProvider<_NetworkRefreshNotifier, int>(
  _NetworkRefreshNotifier.new,
);
