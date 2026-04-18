import 'package:intl/intl.dart';

class PriceFormatter {
  const PriceFormatter._();

  static final NumberFormat _currency = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 0,
  );

  static String format(double value) => _currency.format(value.round());
}
