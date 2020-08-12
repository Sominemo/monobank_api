import 'package:monobank_api/data/currency/countries.dart';

import '../../money.dart';

/// Currency countries pack
///
/// Adds reference information about in which countries
/// currencies are being used
extension CurrencyCountries on Currency {
  /// List of countries currency is being used in
  ///
  /// You can use it as reference information, but don't rely on it too much
  ///
  /// Some countries have their prefixes in brackets after them, for example,
  /// `United Kingdom (the)`. You might want to change that before
  /// displaying to the end user
  List<String> get countries =>
      Iso4217Countries[number.toString()] ?? [];
}
