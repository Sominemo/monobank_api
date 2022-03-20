import 'package:monobank_api/monobank_api.dart';

// Connecting emoji dataset for MCC (transaction category)
import 'package:monobank_api/mcc/extensions/mcc_emoji.dart';

// Connecting names dataset for Currency
import 'package:monobank_api/currency/extensions/currency_names.dart';

void statement() async {
  // Create client
  final client = MonoAPI('token');

// Request client
  final res = await client.clientInfo();

// Get first account
  final account = res.accounts[0];

  // Get statement list for last 3 months
  final statement = account.statement(
      DateTime.now().subtract(Duration(days: 31 * 3)), DateTime.now());

// For each statement item
  await for (final item in statement.list(reverse: true)) {
    // Output string representation
    print('${item.mcc.emoji} $item (${item.operationAmount.currency.name})');
  }
}

void money() {
  // Money supports mathematical operators
  // First argument is amount in the smallest currency unit
  assert(Money(356, Currency.dummy) + Money(20, Currency.dummy) ==
      Money(376, Currency.dummy));

  // Money supports negative values
  assert(Money(356, Currency.dummy) + Money(-20, Currency.dummy) ==
      Money(336, Currency.dummy));

  // Money implements Comparable
  final m = [
    Money(20, Currency.dummy),
    Money(-5, Currency.dummy),
    Money(3, Currency.dummy)
  ];
  m.sort((a, b) => a.compareTo(b));

  assert(m[0] == Money(-5, Currency.dummy));
  assert(m[1] == Money(3, Currency.dummy));
  assert(m[2] == Money(20, Currency.dummy));

  // Convert currencies
  final converter = CurrencyInfo(
    Currency.code('EUR'),
    Currency.code('USD'),
    1.165,
    1.182,
    rounding: MoneyRounding.floor,
  );

  assert(converter.exchange(Money(5000, Currency.code('EUR'))) ==
      Money(5825, Currency.code('USD')));
}

void currency() async {
  // Creating client
  final client = MonoAnonymousAPI();

  // Getting currencies
  final cur = await client.currency();

  // Looking for RUB exchanger
  final currencyInfo =
      cur.firstWhere((e) => e.currencyA == Currency.code('RUB'));

  // Exchanging 100 UAHs to RUB
  final result = currencyInfo.exchange(Money(10000, Currency.code('UAH')));

  // Printing
  print(result);
}
