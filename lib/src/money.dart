import 'dart:math';

import '../data/currency/iso4217_dataset.dart';

const Map<String, String> _currencyStyling = {
  'UAH': '\u20B4',
  'RUB': '\u20bd',
  'USD': '\u0024',
  'EUR': '\u20AC',
  'PLN': 'z\u0142',
  'BGN': '\u043B\u0432',
  'GBP': '\u00A3',
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
  /// Currency instance is immutable
  const Currency(this.code, this.number, this.digits);

  /// ISO-4217 Currency code in `XXX` format
  final String code;

  /// ISO-4217 Currency number
  ///
  /// Is being used for comparison
  final int number;

  /// Length of the fraction part of a currency
  ///
  /// - for `134.23` it will be `2`
  /// - for `165` it will be `0`
  /// - for `111.2` it will be `1`
  final int digits;

  /// Find currency by XXX ISO-4217 code
  ///
  /// Case insensitive
  ///
  /// Returns [UnknownCurrency] if fails
  factory Currency.code(
    /// XXX code to look for
    String code,
  ) {
    final upperCode = code.toUpperCase();
    final info = Iso4217.firstWhere((currency) => currency['code'] == upperCode,
        orElse: () => <String, dynamic>{});

    if (!info.containsKey('code')) return UnknownCurrency(code);

    return Currency(
      info['code'] as String,
      info['number'] as int,
      info['digits'] as int,
    );
  }

  /// Find currency by ISO-4217 currency number
  ///
  /// Returns [UnknownCurrency] if fails
  factory Currency.number(
    /// ISO-4217 number to look for
    int number,
  ) {
    final info = Iso4217.firstWhere((currency) => currency['number'] == number,
        orElse: () => <String, dynamic>{});

    if (!info.containsKey('code')) return UnknownCurrency(number.toString());

    return Currency(
      info['code'] as String,
      info['number'] as int,
      info['digits'] as int,
    );
  }

  /// Dummy currency
  ///
  /// Used for operations with [Money] without currency which require
  /// currency quantity
  static const Currency dummy = Currency('XXX', 999, 2);

  @override
  int get hashCode {
    var result = 15;
    result = 34 * result + number;
    return result;
  }

  /// The quantity operator
  ///
  /// Comparison depends on [Currency.number] field
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
  UnknownCurrency(String code) : super(code, 0, 2);

  /// hashCode of an unknown currency is always `0`
  @override
  int get hashCode => 0;

  @override
  bool operator ==(dynamic other) {
    return identical(this, other);
  }
}

/// Represents money
///
/// Supports `+`, `-`, `/`, `*`, `%` and all comparison operators, but works only
/// with instances of the same currency. See [CurrencyInfo] to exchange
/// currencies by rate
class Money implements Comparable<Money> {
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
      '${toNumericString()} ${fancyCurrencies && _currencyStyling.containsKey(currency.code) ? _currencyStyling[currency.code]! : currency.code}';

  /// Returns `true` if the amount is `0`
  bool get isZero => amount == 0;

  /// Returns `true` if the amount is < `0`
  bool get isNegative => amount < 0;

  /// Returns new Money instance of the same currency with
  /// absolute value of amount
  factory Money.abs(Money target) =>
      Money(target.amount.abs(), target.currency);

  /// Converts double to integer which represents amount of the instance
  /// in the smallest unit of the currency
  ///
  /// Use it if your money information is given as a float and
  /// you need to do some operations with it
  factory Money.float(double amount, Currency currency) =>
      Money((amount * pow(10, currency.digits)).floor(), currency);

  /// Accepts main and fractional part of the amount as two integers
  factory Money.separated(int integer, int fraction, Currency currency) =>
      Money(integer * pow(10, currency.digits).floor() + fraction, currency);

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

  @override
  int compareTo(other) {
    if (this > other) return 1;
    if (this < other) return -1;
    return 0;
  }

  /// The quantity operator
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

  /// Subtracts amount of the second [Money] operand and creates new instance
  ///
  /// Throws exception if currencies do not equal (see [Currency.==])
  Money operator -(Money other) {
    if (currency != other.currency) _throwCurrencyError();

    return Money(amount - other.amount, currency);
  }

  /// Divides amount of the [Money] on integer operand and creates new instance
  ///
  /// The result amount is being floored
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

  /// Selects minimal value among passed
  ///
  /// Throws if 0 items or on different currencies
  static Money min(
    /// Items to check
    ///
    /// Must not be empty
    List<Money> items,
  ) {
    if (items.isEmpty) throw Exception('Minimal 1 item expected');
    var m = items[0];
    for (final e in items) {
      if (e < m) m = e;
    }
    return m;
  }

  /// Selects maximal value among passed
  ///
  /// Throws if 0 items or on different currencies
  static Money max(
    /// Items to check
    ///
    /// Must not be empty
    List<Money> items,
  ) {
    if (items.isEmpty) throw Exception('Minimal 1 item expected');
    var m = items[0];
    for (final e in items) {
      if (e > m) m = e;
    }
    return m;
  }
}

/// Available rounding algos
///
/// Used for exchange in [CurrencyInfo]
enum MoneyRounding {
  /// Floor numbers
  ///
  /// Whole part that's less than the smallest unit of the currency will be ignored
  /// without impact on the final number
  floor,

  /// Mathematical rounding
  ///
  /// Uses usual rounding to smallest unit of the currency
  math,

  /// Half to even rounding
  ///
  /// Also known as banker's rounding. Rounds depending on oddness of the number.
  bank
}

/// Currency converter
///
/// Helps converting different currencies with specified rate
class CurrencyInfo {
  /// Currency converter object
  ///
  /// Accepts two currencies, sell and buy rate of currency A relative to currency B
  ///
  /// Optionally you can specify rounding for the currency exchange
  CurrencyInfo(
    this.currencyA,
    this.currencyB,
    this.rateSell,
    this.rateBuy,
    this.date, {
    this.rounding = MoneyRounding.bank,
  });

  /// Currency to be sold or bought
  final Currency currencyA;

  /// Currency towards which conversion rates are specified
  final Currency currencyB;

  /// Rate which is being used when Currency A is being sold
  final double rateSell;

  /// Rate which is being used when Currency A is being bought
  final double rateBuy;

  /// Currency update date
  final DateTime date;

  /// Used rounding mode for operations.
  ///
  /// See [MoneyRounding]
  final MoneyRounding rounding;

  /// Checks if sell rate is the same with buy rate
  ///
  /// Shortcut for [rateSell] == [rateBuy]
  bool get isCross => rateSell == rateBuy;

  int _round(double n) {
    if (rounding == MoneyRounding.bank) {
      var l = (n * 10).abs().floor();
      if (l % 2 != 0) l += 10;
      if (n < 0) l = -l;
      return (l / 10).floor();
    }
    if (rounding == MoneyRounding.floor) {
      return n.floor();
    }
    if (rounding == MoneyRounding.math) {
      return n.round();
    }
    throw Exception('Unsupported rounding');
  }

  /// Buys or sells [currencyA]
  ///
  /// - If money of [currencyA] is being passed, it's being sold and [currencyB] is being returned
  /// - If money of [currencyB] is being passed, [currencyA] is being bought returned
  ///
  /// If none of above, Exception is thrown
  Money exchange(
    /// Amount to exchange
    Money amount,
  ) {
    if (amount.currency == currencyA) {
      return Money(_round(amount.amount * rateSell), currencyB);
    }

    if (amount.currency == currencyB) {
      return Money(_round(amount.amount / rateBuy), currencyA);
    }

    throw Exception('This currency is not supported by this constructor');
  }

  /// Shortcut to create conversion objects with same sell rate and currency rate
  factory CurrencyInfo.cross(
    Currency currencyA,
    Currency currencyB,
    double rateCross,
    DateTime date, {
    MoneyRounding rounding = MoneyRounding.bank,
  }) =>
      CurrencyInfo(
        currencyA,
        currencyB,
        rateCross,
        rateCross,
        date,
        rounding: rounding,
      );
}
