import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../templates/providers/templates_provider.dart';
import '../domain/models/app_user_account.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(ref);
});

final currentAccountProvider = StateProvider<AppUserAccount?>((ref) {
  return LocalStorageService.instance.getCurrentAccount();
});

final accountsListProvider = StateProvider<List<AppUserAccount>>((ref) {
  return LocalStorageService.instance.getAllAccounts();
});

class AuthNotifier extends StateNotifier<bool> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(LocalStorageService.instance.isLoggedIn());

  void _refreshAllAccountState() {
    _ref.read(currentAccountProvider.notifier).state = LocalStorageService.instance.getCurrentAccount();
    _ref.read(accountsListProvider.notifier).state = LocalStorageService.instance.getAllAccounts();
    _ref.read(batchesProvider.notifier).loadBatches();
    _ref.read(bureauNameProvider.notifier).reload();
    _ref.read(exchangeRateProvider.notifier).reload();
    _ref.read(buyRateProvider.notifier).reload();
    _ref.read(sellRateProvider.notifier).reload();
    _ref.read(defaultCurrencyProvider.notifier).reload();
    _ref.read(isDarkModeProvider.notifier).reload();
    _ref.read(sizeClassificationEnabledProvider.notifier).reload();
    _ref.read(largeThresholdProvider.notifier).reload();
    _ref.read(templatesProvider.notifier).refresh();
  }

  Future<bool> login(String username, String pin) async {
    final account = LocalStorageService.instance.findAccountByCredentials(username, pin);
    if (account != null) {
      await LocalStorageService.instance.switchAccount(account.id);
      await LocalStorageService.instance.setLoggedIn(true);
      _refreshAllAccountState();
      state = true;
      return true;
    }
    return false;
  }

  Future<void> switchAccount(String accountId) async {
    await LocalStorageService.instance.switchAccount(accountId);
    _refreshAllAccountState();
    state = true;
  }

  Future<AppUserAccount> register({
    required String username,
    required String pin,
    required String bureauName,
    String defaultCurrency = 'سعودي',
  }) async {
    final newAccount = await LocalStorageService.instance.createAccount(
      username: username,
      pin: pin,
      bureauName: bureauName,
      defaultCurrency: defaultCurrency,
    );

    _refreshAllAccountState();
    state = true;
    return newAccount;
  }

  Future<void> logout() async {
    await LocalStorageService.instance.setLoggedIn(false);
    _refreshAllAccountState();
    state = false;
  }
}
