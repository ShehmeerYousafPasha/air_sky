import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/core/utils/price_formatter.dart';
import 'package:air_sky/services/local_storage_service.dart';

class CurrencyController extends StateNotifier<AppCurrency> {
  CurrencyController(this._storage) : super(_storage.getCurrency()) {
    PriceFormatter.setCurrency(state);
  }

  final LocalStorageService _storage;

  Future<void> setCurrency(AppCurrency currency) async {
    if (currency == state) {
      return;
    }

    state = currency;
    PriceFormatter.setCurrency(currency);
    await _storage.saveCurrency(currency);
  }
}
