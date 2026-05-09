import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../data/remote_auth_repository.dart';
import '../domain/auth_repository.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
