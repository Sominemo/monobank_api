import 'dart:math';

import '../data/iso4217.dart';

class Currency {
  Currency(String code, this.number, this.digits, this.name, this.countries)
      : code = code.toUpperCase();

  final String code;
  final int number;
  final int digits;
  final String name;
  final List<String> countries;

  factory Currency.code(String code) {
    var upperCode = code.toUpperCase();
    var info = Iso4217.firstWhere((currency) => currency['code'] == upperCode,
        orElse: () => null);

    if (info == null) return UnknownCurrency(code);

    return Currency(info['code'], info['number'], info['digits'], info['name'],
        info['countries']);
  }

  factory Currency.number(int number) {
    var info = Iso4217.firstWhere((currency) => currency['number'] == number,
        orElse: () => null);

    if (info == null) return UnknownCurrency(number.toString());

    return Currency(info['code'], info['number'], info['digits'], info['name'],
        info['countries']);
  }

  @override
  int get hashCode {
    var result = 15;
    result = 34 * result + number;
    return result;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! Currency) return false;
    if (this is UnknownCurrency || other is UnknownCurrency) return false;
    return number == other.number;
  }
}

class UnknownCurrency extends Currency {
  UnknownCurrency(String code) : super(code, 0, 2, '#$code', []);

  @override
  int get hashCode => 0;
}

class Money {
  Money(this.amount, this.currency);

  final int amount;
  final Currency currency;

  double toDouble() => amount / (pow(10, currency.digits));

  @override
  String toString() => toDouble().toStringAsFixed(2);

  bool isZero() => amount == 0;

  bool isNegative() => amount < 0;

  Money abs() => Money(amount.abs(), currency);

  factory Money.float(double amount, Currency currency) =>
      Money((amount * pow(10, currency.digits)).floor(), currency);

  factory Money.separated(int integer, int fraction, Currency currency) =>
      Money(integer * pow(10, currency.digits) + fraction, currency);

  @override
  int get hashCode {
    var result = 16;
    result = 35 * result + amount;
    result = 35 * result + currency.hashCode;
    return result;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is! Money) throw Exception('Money can be compared only to Money');
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return amount == other.amount;
  }

  bool operator >(Money other) {
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return amount > other.amount;
  }

  bool operator >=(Money other) {
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return amount >= other.amount;
  }

  bool operator <(Money other) {
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return amount < other.amount;
  }

  bool operator <=(Money other) {
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return amount <= other.amount;
  }

  Money operator +(Money other) {
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return Money(amount + other.amount, currency);
  }

  Money operator -(Money other) {
    if (currency != other.currency) throw Exception('Operations with different currencies are not supported');

    return Money(amount - other.amount, currency);
  }

  Money operator /(int other) {
    if (other <= 0) throw Exception('Invalid parameter');
    return Money((amount / other).floor(), currency);
  }

  Money operator %(int other) {
    if (other <= 0) throw Exception('Invalid parameter');
    return Money(amount % other, currency);
  }
}
