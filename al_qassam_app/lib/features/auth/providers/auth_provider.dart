import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(LocalStorageService.instance.isLoggedIn());

  Future<bool> login(String username, String pin) async {
    final valid = LocalStorageService.instance.validateCredentials(username, pin);
    if (valid) {
      if (username.trim().isNotEmpty) {
        await LocalStorageService.instance.setAuthUsername(username.trim());
      }
      await LocalStorageService.instance.setLoggedIn(true);
      state = true;
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await LocalStorageService.instance.setLoggedIn(false);
    state = false;
  }
}
