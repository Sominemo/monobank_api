Monobank API SDK for Dart

Author is not related to monobank team.

## Usage

A simple usage example:

```dart
import 'package:monobank_api/main.dart';

var client = API(
  Uri.parse('https://example.com/'),
  token: 'urRZXWbbxW35gJkMmQ0Nn05poKwaMDB2osbDaooeGgPc',
  globalTimeout: Duration(seconds: 8),
);
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Sominemo/monobank_api/issues
