import 'package:monobank_api/data/currency/names.dart';

import '../../money.dart';

/// Currency names pack
///
/// Adds reference information about how currencies are called
extension CurrencyNames on Currency {
  /// Literal name of currency
  ///
  /// You can use it as reference information, but don't rely on it too much
  String get name => Iso4217Names[code] ?? '';
}
