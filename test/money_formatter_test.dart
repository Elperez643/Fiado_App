import 'package:fiado_app/core/utils/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats money values with comma thousands and dot decimals', () {
    expect(MoneyFormatter.format(1000), '1,000');
    expect(MoneyFormatter.format(15000), '15,000');
    expect(MoneyFormatter.format(1000000), '1,000,000');
    expect(MoneyFormatter.format(50.05), '50.05');
    expect(MoneyFormatter.format(1000.75), '1,000.75');
    expect(MoneyFormatter.format(100000.00), '100,000.00');
    expect(MoneyFormatter.formatCurrency(15250.99), 'RD\$15,250.99');
  });
}
