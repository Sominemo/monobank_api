import 'dart:math';

import '../data/iso4217.dart';

const Map<String, dynamic> _CurrencyStyling = {
  'UAH': '\u8372',
  'RUB': '\u20bd',
  'USD': '\u0024',
  'EUR': '\u20AC',
  'PLN': '\u0122\u0322',
  'BGN': '\u1083\u1074',
  'GBP': '\u0163',
  'JPY': '\u00a5',
};

/// Money currency container
///
/// Is being used for:
/// - visual money representation
/// - fractional part calculations
/// - money operations control
class Currency {
  /// Constructs currency
  ///
  /// Currency instance is immunable
  const Currency(
      this.code, this.number, this.digits, this.name, this.countries);

  /// ISO-4217 Currency code in `XXX` format
  final String code;

  /// ISO-4217 Currency number
  ///
  /// Is being used for comparation
  final int number;

  /// Length of the fraction part of a currency
  ///
  /// - for `134.23` it will be `2`
  /// - for `165` it will be `0`
  /// - for `111.2` it will be `1`
  final int digits;

  /// Literal name of currency
  ///
  /// You can use it as reference information, but don't rely on it too much
  final String name;

  /// List of countries currency is being used in
  ///
  /// You can use it as reference information, but don't rely on it too much
  ///
  /// Some countries have their prefixes in brackets after them, for example,
  /// `United Kingdom (the)`. You might want to change that before
  /// displaying to the end user
  final List<String> countries;

  /// Find currency by XXX ISO-4217 code
  ///
  /// Case insensitive
  ///
  /// Returns [UnknownCurrency] if fails
  factory Currency.code(String code) {
    var upperCode = code.toUpperCase();
    var info = Iso4217.firstWhere((currency) => currency['code'] == upperCode,
        orElse: () => null);

    if (info == null) return UnknownCurrency(code);

    return Currency(info['code'], info['number'], info['digits'], info['name'],
        info['countries']);
  }

  /// Find currency by ISO-4217 currency number
  ///
  /// Returns [UnknownCurrency] if fails
  factory Currency.number(int number) {
    var info = Iso4217.firstWhere((currency) => currency['number'] == number,
        orElse: () => null);

    if (info == null) return UnknownCurrency(number.toString());

    return Currency(info['code'], info['number'], info['digits'], info['name'],
        info['countries']);
  }

  /// Dummy currency
  ///
  /// Used for operations with [Money] without currency which require
  /// currency equantity
  static const Currency dummy = Currency('XXX', 999, 2, 'No currency', []);

  @override
  int get hashCode {
    var result = 15;
    result = 34 * result + number;
    return result;
  }

  /// The equantity operator
  ///
  /// Comparation depends on [Currency.number] field
  ///
  /// [UnknownCurrency] never equals to anything, even itself, except
  /// the exactly same instance
  ///
  /// Use [Currency.dummy] for money manipulations which don't
  /// involve currency
  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! Currency) return false;
    if (this is UnknownCurrency || other is UnknownCurrency) return false;
    return number == other.number;
  }
}

/// Unknown currency
///
/// Special class of currency to identify the fact the currency is
/// unknown
///
/// Never equals to anything, even itself, except the exactly same instance
///
/// Grabs code value from the passed argument for visual representation, but
/// [Currency.number] is always set to `0`, [Currency.digits] is set to `2`
class UnknownCurrency extends Currency {
  /// Creates new Unknown Currency instance
  ///
  /// See [UnknownCurrency] for details
  UnknownCurrency(String code) : super(code, 0, 2, '#$code', []);

  /// hashCode of an unknown currency is always `0`
  @override
  int get hashCode => 0;
}

/// Represents money
///
/// Supports `+`, `-`, `/`, `*`, `%` and all comparation operators, but works only
/// with instances of the same currency. See [CurrencyInfo] to exchange
/// currencies by rate
class Money {
  /// Constructs new money instance
  ///
  /// The money constructor is constant
  ///
  /// First parameter is the amount of money in the smallest unit
  /// of a currency
  const Money(this.amount, this.currency);

  /// Amount of money in the smallest unit of a currency
  final int amount;

  /// The currency of money
  final Currency currency;

  /// Converts money to a double
  ///
  /// Use operators like [Money.+], [Money.-] and others instead of working with
  /// float values since it brings risk of inaccuracy
  double toDouble() => amount / (pow(10, currency.digits));

  /// Converts money to stringified double
  ///
  /// The resulting string always has the same amount of fractional digits
  /// as the currency is set to
  String toNumericString() => toDouble().toStringAsFixed(currency.digits);

  /// Change [Money.toString()] behavior to use special currency symbols
  ///
  /// See [Money.toString()]
  static bool fancyCurrencies = true;

  /// Turns the money object to user-friendly string
  ///
  /// Set [Money.fancyCurrencies] to `false` to change behavior and
  /// don't use special currency symbols from Unicode for available
  /// currencies
  ///
  /// If you set this to `false`, toString() will always return values in
  /// format `a.aa XXX`, where `XXX` is [Currency.code].
  @override
  String toString() =>
      '${toNumericString()} ' +
      (fancyCurrencies && _CurrencyStyling.containsKey(currency.code)
          ? _CurrencyStyling[currency.code]
          : currency.code);

  /// Returns `true` if the amount is `0`
  bool isZero() => amount == 0;

  /// Returns `true` if the amount is < `0`
  bool isNegative() => amount < 0;

  /// Returns new Money instance of the same currency with
  /// absolute value of amount
  Money abs() => Money(amount.abs(), currency);

  /// Converts double to integer which represents amount of the instance
  /// in the smallest unit of the currency
  ///
  /// Use it if your money information is given as a float and
  /// you need to do some operations with it
  factory Money.float(double amount, Currency currency) =>
      Money((amount * pow(10, currency.digits)).floor(), currency);

  /// Accepts main and fractional part of the amount as two integers
  factory Money.separated(int integer, int fraction, Currency currency) =>
      Money(integer * pow(10, currency.digits) + fraction, currency);

  /// Constant for zero amount of a [Currency.dummy] currency
  static const Money zero = Money(0, Currency.dummy);

  @override
  int get hashCode {
    var result = 16;
    result = 35 * result + amount;
    result = 35 * result + currency.hashCode;
    return result;
  }

  void _throwCurrencyError() {
    throw Exception('Operations with different currencies are not supported');
  }

  /// The equantity operator
  ///
  /// Supports only [Money] as an argument, else throws exception
  ///
  /// Always equals to `false` if currencies do not equal (see [Currency.==])
  ///
  /// Compares amount of the instances
  @override
  bool operator ==(dynamic other) {
    if (other is! Money) throw Exception('Money can be compared only to Money');
    if (currency != other.currency) return false;

    return amount == other.amount;
  }

  /// Compares amounts of two [Money] instances
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  bool operator >(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return amount > other.amount;
  }

  /// Compares amounts of two [Money] instances
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  bool operator >=(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return amount >= other.amount;
  }

  /// Compares amounts of two [Money] instances
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  bool operator <(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return amount < other.amount;
  }

  /// Compares amounts of two [Money] instances
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  bool operator <=(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return amount <= other.amount;
  }

  /// Adds amount of the second [Money] operand and creates new instance
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  Money operator +(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return Money(amount + other.amount, currency);
  }

  /// Substracts amount of the second [Money] operand and creates new instance
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  Money operator -(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return Money(amount - other.amount, currency);
  }

  /// Divides amount of the [Money] on integer operand and creates new instance
  /// 
  /// The result amount is beeing floored
  ///
  /// Throws exception if `int == 0`
  Money operator /(int other) {
    if (other == 0) throw Exception('Invalid parameter');
    return Money((amount / other).floor(), currency);
  }

  /// Does euclidean division (mod) of amount of the [Money] on integer operand and
  /// creates new instance
  ///
  /// Throws exception if `int == 0`
  Money operator %(int other) {
    if (other == 0) throw Exception('Invalid parameter');
    return Money(amount % other, currency);
  }

  /// Multiplies amount of the [Money] on integer operand and creates new instance
  Money operator *(int other) {
    return Money(amount * other, currency);
  }
}
