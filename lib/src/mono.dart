import 'package:monobank_api/mcc/mcc.dart';
import 'package:monobank_api/monobank_api.dart';

/// Default library domain that's being used
const String _monoPureDomain = 'https://api.monobank.ua/';

/// Card number
///
/// Whole card number is unknown, but starting and ending numbers are
class Mask {
  Mask._(this.start, this.end);

  /// Few first numbers
  final int start;

  /// Few last numbers
  final int end;

  factory Mask._fromString(String s) {
    var e = s.split('*').map((e) => int.parse(e));
    return Mask._(e.first, e.last);
  }
}

/// Card class
enum CardType { black, white, platinum, iron, yellow, other }

CardType _cardTypeFromString(String type) {
  switch (type) {
    case 'black':
      return CardType.black;
      break;

    case 'white':
      return CardType.white;
      break;

    case 'platinum':
      return CardType.platinum;
      break;

    case 'iron':
      return CardType.iron;
      break;

    case 'yellow':
      return CardType.yellow;
      break;

    default:
      return CardType.other;
  }
}

class BankCard {
  BankCard._(this.mask, this.type);

  /// See [Mask]
  Mask mask;

  /// See [CardType]
  CardType type;
}

class Client {
  Client._fromJson(Map<String, dynamic> data, this.controller)
      : name = data['name'] {
    var accs = List<Map<String, dynamic>>.from(data['accounts']);

    var list = accs.map((e) => Account._fromJson(e, this)).toList();
    const curOrder = ['UAH', 'USD', 'EUR', 'PLN'];

    list.sort((a, b) => a.id.compareTo(b.id));

    List<Account> uah, known, unknown;
    uah = [];
    known = [];
    unknown = [];

    list.forEach((e) {
      List<Account> arr;

      if (e.balance.currency.code == 'UAH') {
        arr = uah;
      } else {
        arr = (curOrder.contains(e.balance.currency.code) ? unknown : known);
      }

      arr.add(e);
    });

    uah.sort((a, b) {
      if (a.cards[0].type == CardType.white &&
          b.cards[0].type != CardType.white) {
        return 1;
      }
      return 0;
    });

    known.sort((a, b) {
      var indA = curOrder.indexOf(a.balance.currency.code);
      var indB = curOrder.indexOf(b.balance.currency.code);
      if (indA < indB) {
        return -1;
      }
      if (indA > indB) {
        return 1;
      }
      return 0;
    });

    accounts.addAll(uah + known + unknown);
  }

  final String name;
  final List<Account> accounts = [];
  final API controller;
}

class Cashback {
  Cashback._(this.amount, this.type);

  final double amount;
  final String type;

  dynamic get object => amount;

  @override
  String toString() => '🎁 $amount';
}

class NoCashback extends Cashback {
  NoCashback._() : super._(0, 'None');
  @override
  String toString() => '';
}

class MoneyCashback extends Cashback {
  MoneyCashback._(int amount, this.currency)
      : super._(amount.toDouble(), currency.code);

  Currency currency;

  @override
  Money get object => Money(amount.floor(), currency);

  @override
  String toString() => '💰 ${object.toString()}';
}

class MilesCashback extends Cashback {
  MilesCashback._(int amount) : super._(amount / 100, 'Miles');

  @override
  String toString() => '✈ ${amount}mi';
}

Cashback _cashback(int amount, String type) {
  var currency = Currency.code(type);
  if (currency is! UnknownCurrency) return MoneyCashback._(amount, currency);

  if (type == 'Miles') return MilesCashback._(amount);
  if (type == 'None') return NoCashback._();
  return Cashback._(amount.toDouble(), type);
}

class StatementItem {
  StatementItem._fromJson(Map<String, dynamic> data, this.account)
      : id = data['id'],
        time = DateTime.fromMillisecondsSinceEpoch(data['time'] * 1000),
        description = data['description'],
        mcc = MCC(data['mcc']),
        amount = Money(data['amount'], account.balance.currency),
        operationAmount = Money(
          data['operationAmount'],
          Currency.number(data['currencyCode']),
        ),
        commissionRate = Money(
          data['commissionRate'],
          Currency.number(data['currencyCode']),
        ),
        cashback = _cashback(data['cashbackAmount'], account.cashbackType),
        balance = Money(
          data['balance'],
          account.balance.currency,
        ),
        comment = data['comment'] ?? '';

  final Account account;
  final String id;
  final DateTime time;
  final String description;
  final MCC mcc;
  final Money amount;
  final Money operationAmount;
  final Money commissionRate;
  final Cashback cashback;
  final Money balance;
  final String comment;

  bool get isOut => amount.isNegative;

  @override
  String toString() {
    var res = '';
    res += '${operationAmount} (${cashback}) $description';
    if (comment.isNotEmpty) res += ' :: $comment';

    return res;
  }
}

class Statement {
  Statement._(this.account, this.from, this.to);

  final Account account;
  final DateTime from;
  final DateTime to;

  static const Duration _maxRange = Duration(days: 31);

  Stream<StatementItem> list({bool ignoreErrors = false}) async* {
    DateTime last = from, go;

    while (last.isBefore(to)) {
      go = last.add(_maxRange);
      if (go.isAfter(to)) go = to;

      var f = (last.millisecondsSinceEpoch / 1000).floor();
      var t = (go.millisecondsSinceEpoch / 1000).floor();

      APIResponse data;
      List<Map<String, dynamic>> body;

      try {
        data = await account.client.controller.call(APIRequest(
          'personal/statement/${account.id}/$f/$t',
          methodId: 'personal/statement',
          useAuth: true,
        ));

        body = List<Map<String, dynamic>>.from(data.body);
      } catch (e) {
        if (!ignoreErrors) rethrow;
        body = [];
      }

      var i = body.map((e) => StatementItem._fromJson(e, account));

      for (var e in i) {
        yield e;
      }

      last = go.add(Duration(seconds: 1));
    }
  }
}

class Account {
  static bool hideCreditLimit = false;

  Account._fromJson(Map<String, dynamic> data, this.client)
      : id = data['id'],
        accountBalance =
            Money(data['balance'], Currency.number(data['currencyCode'])),
        creditLimit =
            Money(data['creditLimit'], Currency.number(data['currencyCode'])),
        cashbackType = data['cashbackType'],
        cards = List<String>.from(data['maskedPan'])
            .map((e) => BankCard._(
                Mask._fromString(e), _cardTypeFromString(data['type'])))
            .toList();

  final String id;
  final Client client;
  final Money accountBalance;
  final Money creditLimit;
  final String cashbackType;
  final List<BankCard> cards;

  Money get pureBalance => (accountBalance - creditLimit);
  Money get balance => (hideCreditLimit ? pureBalance : accountBalance);
  bool get isOverdraft => accountBalance.isNegative;
  bool get isCreditUsed => accountBalance >= creditLimit;

  Statement statement(DateTime from, DateTime to) =>
      Statement._(this, from, to);
}

mixin PersonalMethods on API {
  Future<Client> clientInfo() async {
    var data = await call(APIRequest(
      'personal/client-info',
      methodId: 'personal/client-info',
      useAuth: true,
    ));
    return Client._fromJson(data.body, this);
  }
}

mixin CurrencyMethods on API {
  Future<Iterable<CurrencyInfo>> currency({bool burst = false}) async {
    var data = await call(APIRequest(
      'bank/currency',
      methodId: 'bank/currency',
      settings: (burst ? APIFlags.waiting | APIFlags.skip : APIFlags.waiting),
    ));
    List<Map<String, dynamic>> curs = data.body;
    return curs.map<CurrencyInfo>((e) => CurrencyInfo(
        Currency.number(e['currencyCodeA']),
        Currency.number(e['currencyCodeB']),
        (e.containsKey('rateCross') ? e['rateCross'] : e['rateSell']),
        (e.containsKey('rateCross') ? e['rateCross'] : e['rateBuy'])));
  }
}

class MonoAnonymousAPI extends API with CurrencyMethods {
  MonoAnonymousAPI({String domain = _monoPureDomain})
      : super(
          Uri.parse(domain),
          requestTimeouts: {
            'bank/currency': Duration(minutes: 1),
          },
        );
}

class MonoAPI extends API with CurrencyMethods, PersonalMethods {
  MonoAPI(String token, {String domain = _monoPureDomain})
      : super(
          Uri.parse(domain),
          token: token,
          requestTimeouts: {
            'bank/currency': Duration(minutes: 1),
            'personal/client-info': Duration(minutes: 1),
            'personal/statement': Duration(minutes: 1),
          },
        );
}
