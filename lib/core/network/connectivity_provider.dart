import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current list of active connectivity types whenever it changes.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// True when at least one non-none connectivity type is active.
final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).value;
  if (results == null) return true; // assume online until proven otherwise
  return results.any((r) => r != ConnectivityResult.none);
});
