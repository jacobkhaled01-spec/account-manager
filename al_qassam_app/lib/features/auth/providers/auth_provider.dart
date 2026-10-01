import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../batch_import/providers/batches_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/models/app_user_account.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(ref);
});

final currentAccountProvider = Provider<AppUserAccount?>((ref) {
  // Watch auth state to update when switching accounts
  ref.watch(authStateProvider);
  return LocalStorageService.instance.getCurrentAccount();
});

final accountsListProvider = Provider<List<AppUserAccount>>((ref) {
  ref.watch(authStateProvider);
  return LocalStorageService.instance.getAllAccounts();
});

class AuthNotifier extends StateNotifier<bool> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(LocalStorageService.instance.isLoggedIn());

  Future<bool> login(String username, String pin) async {
    final account = LocalStorageService.instance.findAccountByCredentials(username, pin);
    if (account != null) {
      await LocalStorageService.instance.switchAccount(account.id);
      await LocalStorageService.instance.setLoggedIn(true);

      // Refresh batches & settings to load the new account's isolated database
      _ref.read(batchesProvider.notifier).loadBatches();
      _ref.read(bureauNameProvider.notifier).state = LocalStorageService.instance.getBureauName();
      _ref.read(exchangeRateProvider.notifier).state = LocalStorageService.instance.getExchangeRate();
      _ref.read(defaultCurrencyProvider.notifier).state = LocalStorageService.instance.getDefaultCurrency();
      _ref.read(isDarkModeProvider.notifier).state = LocalStorageService.instance.isDarkMode();

      state = true;
      return true;
    }
    return false;
  }

  Future<void> switchAccount(String accountId) async {
    await LocalStorageService.instance.switchAccount(accountId);
    _ref.read(batchesProvider.notifier).loadBatches();
    _ref.read(bureauNameProvider.notifier).state = LocalStorageService.instance.getBureauName();
    _ref.read(exchangeRateProvider.notifier).state = LocalStorageService.instance.getExchangeRate();
    _ref.read(defaultCurrencyProvider.notifier).state = LocalStorageService.instance.getDefaultCurrency();
    _ref.read(isDarkModeProvider.notifier).state = LocalStorageService.instance.isDarkMode();
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

    // Refresh state for new account
    _ref.read(batchesProvider.notifier).loadBatches();
    _ref.read(bureauNameProvider.notifier).state = LocalStorageService.instance.getBureauName();
    _ref.read(exchangeRateProvider.notifier).state = LocalStorageService.instance.getExchangeRate();
    _ref.read(defaultCurrencyProvider.notifier).state = LocalStorageService.instance.getDefaultCurrency();

    state = true;
    return newAccount;
  }

  Future<void> logout() async {
    await LocalStorageService.instance.setLoggedIn(false);
    state = false;
  }
}
