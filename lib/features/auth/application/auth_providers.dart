import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'auth_dependency_providers.dart';

import 'auth_controller.dart';
import 'auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
