# Monobank API SDK for Dart

This package is unofficial.

Convenient wrappers to work with Monobank API, contains MCC and currency datasets.

Monobank API documentation: https://api.monobank.ua/docs/

Separate package for Monobank Corp API (Monobank Open API for providers): [monobank_api_corp](https://pub.dev/packages/monobank_api_corp)

## Usage

Quick example:

```dart
import 'package:monobank_api/monobank_api.dart';

void main() async {
  var client = MonoAPI('token');
  var res = await client.clientInfo();
  var account = res.accounts
      .where((account) => account.balance.currency == Currency.code('USD'))
      .first;
  var statement = account.statement(
    DateTime.now().subtract(Duration(days: 90)), 
    DateTime.now(),
  );

  await for (var item in statement.list(isReverseChronological: true)) {
    print('$item');
  }
}

```

See other examples in Example.
