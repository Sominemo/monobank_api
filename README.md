# Monobank API SDK for Dart

This package is unofficial

## Usage

Quick example:

```dart
import 'package:monobank_api/monobank_api.dart';

void main() async {
  var client = MonoAPI('token');
  var res = await client.clientInfo();
  var account = res.accounts[0];
  var statement = account.statement(
    DateTime.now().subtract(Duration(days: 31)), 
    DateTime.now(),
  );

  await for (var item in statement.list(isReverseChronological: true)) {
    print('$item');
  }
}

```

See other examples in Example.
