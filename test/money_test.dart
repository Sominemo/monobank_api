import 'package:monobank_api/monobank_api.dart';
import 'package:test/test.dart';

void main() {
  group('Currency', () {
    test('Construct', () {
      var c = Currency('XXX', 999, 2);
      expect(c.code, 'XXX');
    });
    test('Find currency by code', () {
      var c = Currency.code('USD');
      expect(c.number, 840);
    });
    test('Find currency by number', () {
      var c = Currency.number(840);
      expect(c.code, 'USD');
    });
    test('Currencies can equal', () {
      var c1 = Currency.number(840);
      var c2 = Currency.number(840);
      expect(c1 == c2, true);
    });
    test('Currencies can be not equal', () {
      var c1 = Currency.number(840);
      var c2 = Currency.number(978);
      expect(c1 != c2, true);
    });
    test('UnknownCurrency doesn\'t equal to usual currency', () {
      var c1 = Currency.number(840);
      var c2 = UnknownCurrency;
      // ignore: unrelated_type_equality_checks
      expect(c1 != c2, true);
    });
    test('UnknownCurrency doesn\'t equal to self of different instance', () {
      var c1 = UnknownCurrency('XXX');
      var c2 = UnknownCurrency('XXX');
      expect(c1 != c2, true);
    });
    test('UnknownCurrency equals self of the same instance', () {
      var c1 = UnknownCurrency;
      var c2 = c1;
      expect(c1 == c2, true);
    });
  });

  group('Money', () {
    test('Construct zero', () {
      var m = Money(0, Currency.dummy);
      expect(m.amount, 0);
    });
    test('Construct > 0', () {
      var m = Money(5, Currency.dummy);
      expect(m.amount, 5);
    });
    test('Construct < 0', () {
      var m = Money(-5, Currency.dummy);
      expect(m.amount, -5);
    });
    test('Double with 0 digits', () {
      var m = Money(2759, Currency('XXX', 999, 0));
      expect(m.toDouble(), 2759.0);
    });
    test('Double with 1 digit', () {
      var m = Money(2759, Currency('XXX', 999, 1));
      expect(m.toDouble(), 275.9);
    });
    test('Double with 2 digits', () {
      var m = Money(2759, Currency('XXX', 999, 2));
      expect(m.toDouble(), 27.59);
    });
    test('Double with 3 digits', () {
      var m = Money(2759, Currency('XXX', 999, 3));
      expect(m.toDouble(), 2.759);
    });
    test('Double with 4 digits', () {
      var m = Money(2759, Currency('XXX', 999, 4));
      expect(m.toDouble(), 0.2759);
    });
    test('Double with 5 digits', () {
      var m = Money(2759, Currency('XXX', 999, 5));
      expect(m.toDouble(), 0.02759);
    });
    test('Double with 4 digits to string', () {
      var m = Money(2759, Currency('XXX', 999, 4));
      expect(m.toNumericString(), '0.2759');
    });
    test('ToString without fancy currencies', () {
      Money.fancyCurrencies = false;
      var m = Money(2759, Currency.code('USD'));
      expect(m.toString(), '27.59 USD');
    });
    test('ToString with fancy currencies', () {
      Money.fancyCurrencies = true;
      var m = Money(2759, Currency.code('USD'));
      expect(m.toString(), '27.59 \$');
    });
    test('anount == 0 | isZero', () {
      var m = Money(0, Currency.dummy);
      expect(m.isZero, true);
    });
    test('anount == 0 | isNegative', () {
      var m = Money(0, Currency.dummy);
      expect(m.isNegative, false);
    });
    test('anount > 0 | isZero', () {
      var m = Money(5, Currency.dummy);
      expect(m.isZero, false);
    });
    test('anount > 0 | isNegative', () {
      var m = Money(5, Currency.dummy);
      expect(m.isNegative, false);
    });
    test('anount < 0 | isZero', () {
      var m = Money(-5, Currency.dummy);
      expect(m.isZero, false);
    });
    test('anount < 0 | isNegative', () {
      var m = Money(-5, Currency.dummy);
      expect(m.isNegative, true);
    });
    test('abs positive equals', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money.abs(m1);
      expect(m2.amount, m1.amount);
    });
    test('abs negative check', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money.abs(m1);
      expect(m2.amount, 5);
    });
    test('==', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 == m2, true);
    });
    test('>', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 > m2, true);
    });
    test('!>', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 > m2, false);
    });
    test('>=', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 >= m2, true);
    });
    test('!>=', () {
      var m1 = Money(-6, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 >= m2, false);
    });
    test('<', () {
      var m1 = Money(-6, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 < m2, true);
    });
    test('!<', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 < m2, false);
    });
    test('<=', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 <= m2, true);
    });
    test('!<=', () {
      var m1 = Money(-4, Currency.dummy);
      var m2 = Money(-5, Currency.dummy);
      expect(m1 <= m2, false);
    });
    test('Doesn\'t equal on different curency', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money(-5, Currency.code('USD'));
      expect(m1 == m2, false);
    });
    test('Doesn\'t equal on different amount', () {
      var m1 = Money(-5, Currency.dummy);
      var m2 = Money(5, Currency.dummy);
      expect(m1 == m2, false);
    });
    test('positive + positive', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money(6, Currency.dummy);
      expect(m1 + m2, Money(11, Currency.dummy));
    });
    test('positive + negative', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money(-6, Currency.dummy);
      expect(m1 + m2, Money(-1, Currency.dummy));
    });
    test('positive - positive', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money(6, Currency.dummy);
      expect(m1 - m2, Money(-1, Currency.dummy));
    });
    test('positive - negative', () {
      var m1 = Money(5, Currency.dummy);
      var m2 = Money(-6, Currency.dummy);
      expect(m1 - m2, Money(11, Currency.dummy));
    });
    test('positive * positive', () {
      var m1 = Money(5, Currency.dummy);
      expect(m1 * 3, Money(15, Currency.dummy));
    });
    test('positive / positive', () {
      var m1 = Money(15, Currency.dummy);
      expect(m1 / 3, Money(5, Currency.dummy));
    });
    test('positive * negative', () {
      var m1 = Money(5, Currency.dummy);
      expect(m1 * -3, Money(-15, Currency.dummy));
    });
    test('positive / negative', () {
      var m1 = Money(15, Currency.dummy);
      expect(m1 / -3, Money(-5, Currency.dummy));
    });
  });
  group('CurrencyInfo', () {
    test('Construct', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5, 1.6, rounding: MoneyRounding.math);
      expect(i.rateBuy, 1.6);
    });
    test('isCross', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5, 1.5, rounding: MoneyRounding.math);
      expect(i.isCross, true);
    });
    test('!isCross', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5, 1.6, rounding: MoneyRounding.math);
      expect(i.isCross, false);
    });
    test('!Currency.cross', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo.cross(c1, c2, 1.5, rounding: MoneyRounding.math);
      expect(i.rateSell, i.rateBuy);
    });
    test('Exchange 1.5 sell math', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5, 1.6, rounding: MoneyRounding.math);
      var r = i.exchange(Money(2, c1));
      expect(r, Money(3, c2));
    });
    test('Exchange 1.5 buy math', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.6, 1.5, rounding: MoneyRounding.math);
      var r = i.exchange(Money(3, c2));
      expect(r, Money(2, c1));
    });
    test('Exchange 234 -> 1.5694 math', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.math);
      var r = i.exchange(Money(234, c1));
      expect(r, Money(367, c2));
    });
    test('Exchange 235 -> 1.5694 math', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.math);
      var r = i.exchange(Money(235, c1));
      expect(r, Money(369, c2));
    });
    test('Exchange 235 -> 1.5694 floor', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.floor);
      var r = i.exchange(Money(235, c1));
      expect(r, Money(368, c2));
    });
    test('Exchange 235 -> 1.5694 bank', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.bank);
      var r = i.exchange(Money(235, c1));
      expect(r, Money(368, c2));
    });
    test('Exchange 2365 -> 1.5709 bank', () {
      var c1 = Currency('XXX', 999, 2);
      var c2 = Currency('AAA', 000, 2);
      var i = CurrencyInfo(c1, c2, 1.5709, 2, rounding: MoneyRounding.bank);
      var r = i.exchange(Money(235, c1));
      expect(r, Money(370, c2));
    });
    test('min()', () {
      expect(
          Money.min([
            Money(5, Currency.dummy),
            Money(-4, Currency.dummy),
            Money(2, Currency.dummy)
          ]),
          Money(-4, Currency.dummy));
    });
    test('max()', () {
      expect(
          Money.max([
            Money(5, Currency.dummy),
            Money(-4, Currency.dummy),
            Money(2, Currency.dummy)
          ]),
          Money(5, Currency.dummy));
    });
  });
}
