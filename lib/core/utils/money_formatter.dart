import 'package:intl/intl.dart';

class MoneyFormatter {
  static final NumberFormat _integerFormatter = NumberFormat.decimalPattern(
    'en_US',
  );
  static final NumberFormat _decimalFormatter = NumberFormat(
    '#,##0.00',
    'en_US',
  );

  static String format(num value) {
    if (value is int || value % 1 == 0 && value is! double) {
      return _integerFormatter.format(value);
    }
    return _decimalFormatter.format(value);
  }

  static String formatCurrency(num value, {String symbol = 'RD\$'}) {
    return '$symbol${_decimalFormatter.format(value)}';
  }

  static String formatNullable(num? value, {String empty = 'Sin datos'}) {
    if (value == null) return empty;
    return format(value);
  }
}
