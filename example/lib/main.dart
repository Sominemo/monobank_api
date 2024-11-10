import 'dart:convert';
import 'package:monobank_api/monobank_api.dart';

// Connecting emoji dataset for MCC (transaction category)
import 'package:monobank_api/mcc/extensions/mcc_emoji.dart';

// Connecting names dataset for Currency
import 'package:monobank_api/currency/extensions/currency_names.dart';

// Get client statement for last 3 months from the first account
void main() async {
  // Create client
  final mono = MonoAPI('token');

  // Request client
  final client = await mono.clientInfo();

  // List accounts and cards
  for (final account in client.accounts) {
    print('$account');
    for (final card in account.cards) {
      print('  $card');
    }
  }

  // List jars
  for (final jar in client.jars) {
    print('$jar');
  }

  // Get statement list for last 3 months
  final statement = client.accounts[0].statement(
    DateTime.now().subtract(Duration(days: 31 * 3)),
    DateTime.now(),
  );

  // For each statement item
  await for (final item in statement.list(isReverseChronological: true)) {
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
    DateTime.now(),
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

void webhook() async {
  const webhookData = '''
{
  "type": "StatementItem",
  "data": {
    "account": "q5MA8eamezlw-SQjcddOmQ",
    "statementItem": {
      "id": "ZuHWzqkKGVo=",
      "time": 1554466347,
      "description": "Покупка щастя",
      "mcc": 7997,
      "originalMcc": 7997,
      "hold": false,
      "amount": -95000,
      "operationAmount": -95000,
      "currencyCode": 980,
      "commissionRate": 0,
      "cashbackAmount": 19000,
      "balance": 10050000,
      "comment": "За каву",
      "receiptId": "XXXX-XXXX-XXXX-XXXX",
      "invoiceId": "2103.в.27",
      "counterEdrpou": "3096889974",
      "counterIban": "UA898999980000355639201001404"
    }
  }
}
  ''';

  // Parsing webhook data
  final webhookEvent =
      WebhookEvent.fromJson(jsonDecode(webhookData) as Map<String, dynamic>);

  // Checking webhook type
  if (webhookEvent is StatementItemWebhookEvent) {
    // Printing raw statement item
    print('${webhookEvent.item.mcc.emoji} ${webhookEvent.item}');

    // Fetching account data for proper data
    final client = MonoAPI('token');
    await webhookEvent.account.resolve(client);
    final newItem = webhookEvent.item.regenerate();

    // Printing regenerated statement item
    //
    // Here you can see proper cashback type, since this data relies on
    // account data.
    //
    // Also in this example amount == operationAmount, so StatementItem
    // assumes currencyCode is the same as currencyCode of the account.
    //
    // This may be not true in real life, and in such cases you will have
    // [Currency.dummy] currency.
    print('${newItem.mcc.emoji} $newItem');
  }
}
