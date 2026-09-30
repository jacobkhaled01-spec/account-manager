import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_storage_service.dart';

final exchangeRateProvider = StateNotifierProvider<ExchangeRateNotifier, double>((ref) {
  return ExchangeRateNotifier();
});

class ExchangeRateNotifier extends StateNotifier<double> {
  ExchangeRateNotifier() : super(LocalStorageService.instance.getExchangeRate());

  Future<void> updateRate(double newRate) async {
    state = newRate;
    await LocalStorageService.instance.setExchangeRate(newRate);
  }
}

final buyRateProvider = StateNotifierProvider<BuyRateNotifier, double>((ref) {
  return BuyRateNotifier();
});

class BuyRateNotifier extends StateNotifier<double> {
  BuyRateNotifier() : super(LocalStorageService.instance.getBuyRate());

  Future<void> updateBuyRate(double newRate) async {
    state = newRate;
    await LocalStorageService.instance.setBuyRate(newRate);
  }
}

final sellRateProvider = StateNotifierProvider<SellRateNotifier, double>((ref) {
  return SellRateNotifier(ref);
});

class SellRateNotifier extends StateNotifier<double> {
  final Ref _ref;
  SellRateNotifier(this._ref) : super(LocalStorageService.instance.getSellRate());

  Future<void> updateSellRate(double newRate) async {
    state = newRate;
    await LocalStorageService.instance.setSellRate(newRate);
    _ref.read(exchangeRateProvider.notifier).updateRate(newRate);
  }
}

final defaultCurrencyProvider = StateNotifierProvider<DefaultCurrencyNotifier, String>((ref) {
  return DefaultCurrencyNotifier();
});

class DefaultCurrencyNotifier extends StateNotifier<String> {
  DefaultCurrencyNotifier() : super(LocalStorageService.instance.getDefaultCurrency());

  Future<void> updateCurrency(String newCurrency) async {
    state = newCurrency;
    await LocalStorageService.instance.setDefaultCurrency(newCurrency);
  }
}

final bureauNameProvider = StateNotifierProvider<BureauNameNotifier, String>((ref) {
  return BureauNameNotifier();
});

class BureauNameNotifier extends StateNotifier<String> {
  BureauNameNotifier() : super(LocalStorageService.instance.getBureauName());

  Future<void> updateName(String newName) async {
    state = newName;
    await LocalStorageService.instance.setBureauName(newName);
  }
}

final isDarkModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(LocalStorageService.instance.isDarkMode());

  Future<void> toggleTheme() async {
    state = !state;
    await LocalStorageService.instance.setDarkMode(state);
  }
}

final sizeClassificationEnabledProvider = StateNotifierProvider<SizeClassificationEnabledNotifier, bool>((ref) {
  return SizeClassificationEnabledNotifier();
});

class SizeClassificationEnabledNotifier extends StateNotifier<bool> {
  SizeClassificationEnabledNotifier() : super(LocalStorageService.instance.isSizeClassificationEnabled());

  Future<void> toggle() async {
    state = !state;
    await LocalStorageService.instance.setSizeClassificationEnabled(state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await LocalStorageService.instance.setSizeClassificationEnabled(enabled);
  }
}

final largeThresholdProvider = StateNotifierProvider<LargeThresholdNotifier, double>((ref) {
  return LargeThresholdNotifier();
});

class LargeThresholdNotifier extends StateNotifier<double> {
  LargeThresholdNotifier() : super(LocalStorageService.instance.getLargeRemittanceThreshold());

  Future<void> updateThreshold(double newThreshold) async {
    state = newThreshold;
    await LocalStorageService.instance.setLargeRemittanceThreshold(newThreshold);
  }
}
