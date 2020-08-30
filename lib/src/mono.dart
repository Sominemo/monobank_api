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
  final String start;

  /// Few last numbers
  final String end;

  factory Mask._fromString(String s) {
    var e = s.split('*');
    return Mask._(e.first, e.last);
  }

  @override
  String toString() => '$start****$end';
}

/// Card class
///
/// This library statically identifies card types
/// to prevent your app from working with
/// new unexpected ones
enum CardType {
  /// Classic black card, including in foreign currencies
  black,

  /// Debit white card
  white,

  /// Monobank platinum card
  ///
  /// Can have 3 colors, but there's no option to identify it
  platinum,

  /// Card of IRON BANK
  iron,

  /// Children card
  ///
  /// Can have black design but still be identified
  /// as yellow one
  yellow,

  /// FOP
  ///
  /// Account of an individual entrepreneur
  fop,

  /// Unknown card
  other
}

/// Representation of a bank card
///
/// Contains info about account type and known card numbers
class BankCard {
  BankCard._(this.mask, this.type);

  /// See [Mask]
  Mask mask;

  /// See [CardType]
  CardType type;

  /// Turn string to enum
  static CardType cardTypeFromString(
    /// String representation of card type
    String type,
  ) {
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

      case 'fop':
        return CardType.fop;
        break;

      default:
        return CardType.other;
    }
  }
}

/// Representation of clientInfo result
class Client {
  Client._fromJson(Map<String, dynamic> data, this.controller)
      : name = data['name'],
        id = data['clientId'] {
    var accs = List<Map<String, dynamic>>.from(data['accounts']);

    var list = accs.map((e) => Account._fromJson(e, this)).toList();

    if (sortAccounts) {
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
        if (a.type == CardType.white && b.type != CardType.white) {
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
    } else {
      accounts.addAll(list);
    }
  }

  /// Formal name of the client
  final String name;

  /// id of the client in monobank system
  ///
  /// Can be used for send.monobank.ua links
  final String id;

  /// List of available accounts
  ///
  /// Monobank API returns the accounts in
  /// different (and random) order everytime
  ///
  /// For that, this library tries to sort
  /// the accounts to match the order in
  /// official monobank app
  ///
  /// If you don't need sort, see [sortAccounts]
  final List<Account> accounts = [];

  /// Parent of the client
  final API controller;

  /// Controls account sorting
  ///
  /// See [accounts]
  ///
  /// - `true`: enable sorting
  /// - `false`: disable sorting
  static bool sortAccounts = true;
}

/// Representation of cashback
class Cashback {
  Cashback._(this.amount, this.type);

  /// Amount of cashback
  final double amount;

  /// String representation of cashback type
  final String type;

  /// Related object to the Cashback
  ///
  /// double amount, if not overriden
  dynamic get object => amount;

  @override
  String toString() => '🎁 $amount';
}

/// Account doesn't provide cashback
class NoCashback extends Cashback {
  NoCashback._() : super._(0, 'None');
  @override
  String toString() => '';
}

/// Account provides money-backed cashback
class MoneyCashback extends Cashback {
  MoneyCashback._(int amount, this.currency)
      : super._(amount.toDouble(), currency.code);

  /// The currency of cashback
  Currency currency;

  @override
  Money get object => Money(amount.floor(), currency);

  @override
  String toString() => '💰 ${object.toString()}';
}

/// Account provides miles cashback
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

/// Single item from statement
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
        comment = data['comment'] ?? '',
        hold = data['hold'];

  /// Parent account
  final Account account;

  /// Operation ID
  final String id;

  /// Timestamp
  final DateTime time;

  /// Title
  final String description;

  /// Category
  final MCC mcc;

  /// Amount in account currency
  final Money amount;

  /// Amount in original currency (e.g. USD, RUB)
  final Money operationAmount;

  /// Commission rate in original currency (e.g. USD, RUB)
  final Money commissionRate;

  /// Cashback
  final Cashback cashback;

  /// Balance of the account at the time
  final Money balance;

  /// User comment if available
  final String comment;

  /// Authorization hold
  final bool hold;

  /// Returns true if operation is outgoing
  bool get isOut => amount.isNegative;

  @override
  String toString() {
    var res = '';
    res += '$time | $operationAmount ($cashback) $description';
    if (comment.isNotEmpty) res += ' :: $comment';

    return res;
  }
}

/// Statement stream holder
///
/// Use [list] method to access statement
class Statement {
  Statement._(this.account, this.from, this.to);

  /// Source account
  final Account account;

  /// Start from
  final DateTime from;

  /// End on
  final DateTime to;

  static const Duration _maxRange = Duration(days: 31);

  /// Begins stream of statement
  ///
  /// Items are being delivered as fast as possible if specified
  /// range is bigger than the one allowed by API
  ///
  /// In such case statement is being requested by parts
  Stream<StatementItem> list({
    /// Doesn't stop the stream if an error happens
    ///
    /// Some items can be skipped without any warnings
    bool ignoreErrors = false,

    /// Reverse stream
    ///
    /// `false`: from older to newer
    /// `true`: from newer to older
    bool reverse = false,
  }) async* {
    var lFrom = from, lTo = to;

    while (reverse ? lTo.isAfter(from) : lFrom.isBefore(to)) {
      if (reverse) {
        lFrom = lTo.subtract(_maxRange);
        if (lFrom.isBefore(from)) lFrom = from;
      } else {
        lTo = lFrom.add(_maxRange);
        if (lTo.isAfter(to)) lTo = to;
      }

      var f = (lFrom.millisecondsSinceEpoch / 1000).floor();
      var t = (lTo.millisecondsSinceEpoch / 1000).floor();

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

      var i = (reverse ? body : body.reversed)
          .map((e) => StatementItem._fromJson(e, account));

      for (var e in i) {
        yield e;
      }

      if (reverse) {
        lTo = lFrom.subtract(Duration(seconds: 1));
      } else {
        lFrom = lTo.add(Duration(seconds: 1));
      }
    }
  }
}

/// Represents monobank account (balance)
class Account {
  /// Extracts credit limit from account balance for [balance] getter
  /// to show true account balance
  ///
  /// You can also use [pureBalance] instead
  static bool hideCreditLimit = false;

  Account._fromJson(Map<String, dynamic> data, this.client)
      : id = data['id'],
        accountBalance =
            Money(data['balance'], Currency.number(data['currencyCode'])),
        creditLimit =
            Money(data['creditLimit'], Currency.number(data['currencyCode'])),
        cashbackType = data['cashbackType'],
        iban = data['iban'],
        type = BankCard.cardTypeFromString(data['type']),
        cards = List<String>.from(data['maskedPan'])
            .map((e) => BankCard._(
                  Mask._fromString(e),
                  BankCard.cardTypeFromString(data['type']),
                ))
            .toList();

  /// Account ID
  ///
  /// Actually can be used for getting statement only
  final String id;

  /// Parent
  final Client client;

  /// Reported account balance (including credit limit)
  final Money accountBalance;

  /// Credit limit
  final Money creditLimit;

  /// Cashback type
  final String cashbackType;

  /// IBAN
  final String iban;

  /// List of related cards
  final List<BankCard> cards;

  /// Account type
  ///
  /// See [CardType]
  final CardType type;

  /// Account balance without credit funds
  Money get pureBalance => (accountBalance - creditLimit);

  /// Account balance
  ///
  /// Returns accountBalance or pureBalance
  /// depending on [hideCreditLimit] flag
  Money get balance => (hideCreditLimit ? pureBalance : accountBalance);

  /// Returns true when the account is in actual overdraft
  ///
  /// This means balance owes more than balance
  /// and credit limit combined
  bool get isOverdraft => accountBalance.isNegative;

  /// Returns true when credit funds are being used or the account
  /// is in overdraft
  bool get isCreditUsed => accountBalance < creditLimit;

  /// Get statement object for current account
  ///
  /// See [Statement]
  Statement statement(DateTime from, DateTime to) =>
      Statement._(this, from, to);
}

/// Enable personal/* methods
///
/// Gives access to Client, Account and Statement objects
mixin PersonalMethods on API {
  /// Request Client object
  Future<Client> clientInfo() async {
    var data = await call(APIRequest(
      'personal/client-info',
      methodId: 'personal/client-info',
      useAuth: true,
    ));
    return Client._fromJson(data.body, this);
  }
}

/// Enable bank/currency method
mixin CurrencyMethods on API {
  /// Get currencies
  ///
  /// Generates CurrencyInfo's from
  /// monobank currency dataF
  Future<Iterable<CurrencyInfo>> currency({bool burst = false}) async {
    var data = await call(APIRequest(
      'bank/currency',
      methodId: 'bank/currency',
      settings: (burst ? APIFlags.waiting | APIFlags.skip : APIFlags.waiting),
    ));
    var curs = List<Map<String, dynamic>>.from(data.body);
    return curs.map<CurrencyInfo>((e) => CurrencyInfo(
        Currency.number(e['currencyCodeA']),
        Currency.number(e['currencyCodeB']),
        (e.containsKey('rateCross') ? e['rateCross'] : e['rateSell']),
        (e.containsKey('rateCross') ? e['rateCross'] : e['rateBuy'])));
  }
}

/// Anonymous monobank API client
///
/// Can be used for currency getting
class MonoAnonymousAPI extends API with CurrencyMethods {
  /// New anonymous client
  MonoAnonymousAPI({String domain = _monoPureDomain})
      : super(
          Uri.parse(domain),
          requestTimeouts: {
            'bank/currency': Duration(minutes: 1),
          },
        );
}

/// Personal token API
///
/// For personal use only. Get token on https://api.monobank,ua
///
/// Supports currency getting and personal/* methods
class MonoAPI extends API with CurrencyMethods, PersonalMethods {
  /// New personal token client
  ///
  /// See [MonoAPI]
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
