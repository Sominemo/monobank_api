import 'package:monobank_api/monobank_api.dart';

// Connecting emoji dataset for MCC (transaction category)
import 'package:monobank_api/mcc/extensions/emoji.dart';

// Connecting names dataset for Currency
import 'package:monobank_api/currency/extensions/names.dart';

void main() async {
  // Create client
  var client = MonoAPI('token');

// Request client
  var res = await client.clientInfo();

// Get first account
  var account = res.accounts[0];

  // Get statement list for last 3 months
  var statement = account.statement(
      DateTime.now().subtract(Duration(days: 31 * 3)), DateTime.now());

// For each statement item
  await for (var item in statement.list(reverse: true)) {
    // Output string representation
    print('${item.mcc.emoji} $item (${item.operationAmount.currency.name})');
  }
}
