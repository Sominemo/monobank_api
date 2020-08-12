import 'package:monobank_api/monobank_api.dart';

void main() {
  // Money supports mathematical operators
  // First argument is amount in the smallest currency unit
  assert(Money(356, Currency.dummy) + Money(20, Currency.dummy) ==
      Money(376, Currency.dummy));

  // Money supports negative values
  assert(Money(356, Currency.dummy) + Money(-20, Currency.dummy) ==
      Money(336, Currency.dummy));

  // Money implements Comparable
  var m = [
    Money(20, Currency.dummy),
    Money(-5, Currency.dummy),
    Money(3, Currency.dummy)
  ];
  m.sort((a, b) => a.compareTo(b));

  assert(m[0] == Money(-5, Currency.dummy));
  assert(m[1] == Money(3, Currency.dummy));
  assert(m[2] == Money(20, Currency.dummy));

  // Convert currencies
  var converter = CurrencyInfo(
    Currency.code('EUR'),
    Currency.code('USD'),
    1.165,
    1.182,
    rounding: MoneyRounding.floor,
  );

  assert(converter.exchange(Money(5000, Currency.code('EUR'))) ==
      Money(5825, Currency.code('USD')));
}
