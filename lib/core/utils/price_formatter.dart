import 'package:intl/intl.dart';

enum AppCurrency { usd, pkr, eur, gbp, aed }

class _CurrencyDefinition {
  const _CurrencyDefinition({
    required this.code,
    required this.symbol,
    required this.usdRate,
  });

  final String code;
  final String symbol;
  final double usdRate;
}

class PriceFormatter {
  const PriceFormatter._();

  static const Map<AppCurrency, _CurrencyDefinition> _definitions =
      <AppCurrency, _CurrencyDefinition>{
        AppCurrency.usd: _CurrencyDefinition(
          code: 'USD',
          symbol: '\$',
          usdRate: 1,
        ),
        AppCurrency.pkr: _CurrencyDefinition(
          code: 'PKR',
          symbol: 'Rs ',
          usdRate: 280,
        ),
        AppCurrency.eur: _CurrencyDefinition(
          code: 'EUR',
          symbol: 'EUR ',
          usdRate: 0.92,
        ),
        AppCurrency.gbp: _CurrencyDefinition(
          code: 'GBP',
          symbol: 'GBP ',
          usdRate: 0.79,
        ),
        AppCurrency.aed: _CurrencyDefinition(
          code: 'AED',
          symbol: 'AED ',
          usdRate: 3.67,
        ),
      };

  static AppCurrency _selectedCurrency = AppCurrency.usd;

  static AppCurrency get selectedCurrency => _selectedCurrency;

  static void setCurrency(AppCurrency currency) {
    _selectedCurrency = currency;
  }

  static String currencyCode(AppCurrency currency) {
    return _definitions[currency]!.code;
  }

  static String currencyLabel(AppCurrency currency) {
    final _CurrencyDefinition definition = _definitions[currency]!;
    return '${definition.code} (${definition.symbol.trim()})';
  }

  static AppCurrency parseCurrency(String rawCode) {
    final String normalized = rawCode.trim().toUpperCase();
    for (final MapEntry<AppCurrency, _CurrencyDefinition> entry
        in _definitions.entries) {
      if (entry.value.code == normalized) {
        return entry.key;
      }
    }
    return AppCurrency.usd;
  }

  static double convertUsd(double usdValue, {AppCurrency? toCurrency}) {
    final _CurrencyDefinition definition =
        _definitions[toCurrency ?? _selectedCurrency]!;
    return usdValue * definition.usdRate;
  }

  static double convertToUsd(
    double currencyAmount, {
    AppCurrency? fromCurrency,
  }) {
    final _CurrencyDefinition definition =
        _definitions[fromCurrency ?? _selectedCurrency]!;
    return currencyAmount / definition.usdRate;
  }

  static String format(double usdValue, {AppCurrency? currency}) {
    final AppCurrency resolvedCurrency = currency ?? _selectedCurrency;
    final _CurrencyDefinition definition = _definitions[resolvedCurrency]!;
    final NumberFormat formatter = NumberFormat.currency(
      symbol: definition.symbol,
      decimalDigits: 0,
    );

    final double convertedAmount = convertUsd(
      usdValue,
      toCurrency: resolvedCurrency,
    );
    return formatter.format(convertedAmount.round());
  }
}
