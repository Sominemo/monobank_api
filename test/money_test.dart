import 'package:monobank_api/monobank_api.dart';
import 'package:test/test.dart';

void main() {
  group('Currency', () {
    test('Construct', () {
      final c = Currency('XXX', 999, 2);
      expect(c.code, 'XXX');
    });
    test('Find currency by code', () {
      final c = Currency.code('USD');
      expect(c.number, 840);
    });
    test('Find currency by number', () {
      final c = Currency.number(840);
      expect(c.code, 'USD');
    });
    test('Currencies can equal', () {
      final c1 = Currency.number(840);
      final c2 = Currency.number(840);
      expect(c1 == c2, true);
    });
    test('Currencies can be not equal', () {
      final c1 = Currency.number(840);
      final c2 = Currency.number(978);
      expect(c1 != c2, true);
    });
    test('UnknownCurrency doesn\'t equal to usual currency', () {
      final c1 = Currency.number(840);
      final c2 = UnknownCurrency;
      // ignore: unrelated_type_equality_checks
      expect(c1 != c2, true);
    });
    test('UnknownCurrency doesn\'t equal to self of different instance', () {
      final c1 = UnknownCurrency('XXX');
      final c2 = UnknownCurrency('XXX');
      expect(c1 != c2, true);
    });
    test('UnknownCurrency equals self of the same instance', () {
      final c1 = UnknownCurrency;
      final c2 = c1;
      expect(c1 == c2, true);
    });
  });

  group('Money', () {
    test('Construct zero', () {
      final m = Money(0, Currency.dummy);
      expect(m.amount, 0);
    });
    test('Construct > 0', () {
      final m = Money(5, Currency.dummy);
      expect(m.amount, 5);
    });
    test('Construct < 0', () {
      final m = Money(-5, Currency.dummy);
      expect(m.amount, -5);
    });
    test('Double with 0 digits', () {
      final m = Money(2759, Currency('XXX', 999, 0));
      expect(m.toDouble(), 2759.0);
    });
    test('Double with 1 digit', () {
      final m = Money(2759, Currency('XXX', 999, 1));
      expect(m.toDouble(), 275.9);
    });
    test('Double with 2 digits', () {
      final m = Money(2759, Currency('XXX', 999, 2));
      expect(m.toDouble(), 27.59);
    });
    test('Double with 3 digits', () {
      final m = Money(2759, Currency('XXX', 999, 3));
      expect(m.toDouble(), 2.759);
    });
    test('Double with 4 digits', () {
      final m = Money(2759, Currency('XXX', 999, 4));
      expect(m.toDouble(), 0.2759);
    });
    test('Double with 5 digits', () {
      final m = Money(2759, Currency('XXX', 999, 5));
      expect(m.toDouble(), 0.02759);
    });
    test('Double with 4 digits to string', () {
      final m = Money(2759, Currency('XXX', 999, 4));
      expect(m.toNumericString(), '0.2759');
    });
    test('ToString without fancy currencies', () {
      Money.fancyCurrencies = false;
      final m = Money(2759, Currency.code('USD'));
      expect(m.toString(), '27.59 USD');
    });
    test('ToString with fancy currencies', () {
      Money.fancyCurrencies = true;
      final m = Money(2759, Currency.code('USD'));
      expect(m.toString(), '27.59 \$');
    });
    test('amount == 0 | isZero', () {
      final m = Money(0, Currency.dummy);
      expect(m.isZero, true);
    });
    test('amount == 0 | isNegative', () {
      final m = Money(0, Currency.dummy);
      expect(m.isNegative, false);
    });
    test('amount > 0 | isZero', () {
      final m = Money(5, Currency.dummy);
      expect(m.isZero, false);
    });
    test('amount > 0 | isNegative', () {
      final m = Money(5, Currency.dummy);
      expect(m.isNegative, false);
    });
    test('amount < 0 | isZero', () {
      final m = Money(-5, Currency.dummy);
      expect(m.isZero, false);
    });
    test('amount < 0 | isNegative', () {
      final m = Money(-5, Currency.dummy);
      expect(m.isNegative, true);
    });
    test('abs positive equals', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money.abs(m1);
      expect(m2.amount, m1.amount);
    });
    test('abs negative check', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money.abs(m1);
      expect(m2.amount, 5);
    });
    test('==', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 == m2, true);
    });
    test('>', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 > m2, true);
    });
    test('!>', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 > m2, false);
    });
    test('>=', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 >= m2, true);
    });
    test('!>=', () {
      final m1 = Money(-6, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 >= m2, false);
    });
    test('<', () {
      final m1 = Money(-6, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 < m2, true);
    });
    test('!<', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 < m2, false);
    });
    test('<=', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 <= m2, true);
    });
    test('!<=', () {
      final m1 = Money(-4, Currency.dummy);
      final m2 = Money(-5, Currency.dummy);
      expect(m1 <= m2, false);
    });
    test('Doesn\'t equal on different currency', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money(-5, Currency.code('USD'));
      expect(m1 == m2, false);
    });
    test('Doesn\'t equal on different amount', () {
      final m1 = Money(-5, Currency.dummy);
      final m2 = Money(5, Currency.dummy);
      expect(m1 == m2, false);
    });
    test('positive + positive', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money(6, Currency.dummy);
      expect(m1 + m2, Money(11, Currency.dummy));
    });
    test('positive + negative', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money(-6, Currency.dummy);
      expect(m1 + m2, Money(-1, Currency.dummy));
    });
    test('positive - positive', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money(6, Currency.dummy);
      expect(m1 - m2, Money(-1, Currency.dummy));
    });
    test('positive - negative', () {
      final m1 = Money(5, Currency.dummy);
      final m2 = Money(-6, Currency.dummy);
      expect(m1 - m2, Money(11, Currency.dummy));
    });
    test('positive * positive', () {
      final m1 = Money(5, Currency.dummy);
      expect(m1 * 3, Money(15, Currency.dummy));
    });
    test('positive / positive', () {
      final m1 = Money(15, Currency.dummy);
      expect(m1 / 3, Money(5, Currency.dummy));
    });
    test('positive * negative', () {
      final m1 = Money(5, Currency.dummy);
      expect(m1 * -3, Money(-15, Currency.dummy));
    });
    test('positive / negative', () {
      final m1 = Money(15, Currency.dummy);
      expect(m1 / -3, Money(-5, Currency.dummy));
    });
  });
  group('CurrencyInfo', () {
    test('Construct', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5, 1.6, rounding: MoneyRounding.math);
      expect(i.rateBuy, 1.6);
    });
    test('isCross', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5, 1.5, rounding: MoneyRounding.math);
      expect(i.isCross, true);
    });
    test('!isCross', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5, 1.6, rounding: MoneyRounding.math);
      expect(i.isCross, false);
    });
    test('!Currency.cross', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo.cross(c1, c2, 1.5, rounding: MoneyRounding.math);
      expect(i.rateSell, i.rateBuy);
    });
    test('Exchange 1.5 sell math', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5, 1.6, rounding: MoneyRounding.math);
      final r = i.exchange(Money(2, c1));
      expect(r, Money(3, c2));
    });
    test('Exchange 1.5 buy math', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.6, 1.5, rounding: MoneyRounding.math);
      final r = i.exchange(Money(3, c2));
      expect(r, Money(2, c1));
    });
    test('Exchange 234 -> 1.5694 math', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.math);
      final r = i.exchange(Money(234, c1));
      expect(r, Money(367, c2));
    });
    test('Exchange 235 -> 1.5694 math', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.math);
      final r = i.exchange(Money(235, c1));
      expect(r, Money(369, c2));
    });
    test('Exchange 235 -> 1.5694 floor', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.floor);
      final r = i.exchange(Money(235, c1));
      expect(r, Money(368, c2));
    });
    test('Exchange 235 -> 1.5694 bank', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5694, 2, rounding: MoneyRounding.bank);
      final r = i.exchange(Money(235, c1));
      expect(r, Money(368, c2));
    });
    test('Exchange 2365 -> 1.5709 bank', () {
      final c1 = Currency('XXX', 999, 2);
      final c2 = Currency('AAA', 000, 2);
      final i = CurrencyInfo(c1, c2, 1.5709, 2, rounding: MoneyRounding.bank);
      final r = i.exchange(Money(235, c1));
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
