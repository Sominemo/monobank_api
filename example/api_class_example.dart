import 'package:monobank_api/monobank_api.dart';
import 'package:monobank_api/mcc/extensions/emoji.dart';


// Grabbing statement for last 3 months
void main() async {
  var client = MonoAPI('urRPXWhbxw35g');

  var res = await client.clientInfo();
  var s = res.accounts[0]
      .statement(DateTime.now().subtract(Duration(days: 31 * 3)), DateTime.now());
  await for (var item in s.list()) {
    print('${item.mcc.emoji} $item\n');
  }
}
