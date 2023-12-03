import 'package:monobank_api/mcc.dart';
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
    final e = s.split('*');
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

  /// "єПідтримка" card
  ///
  /// Account for aid money from the Ukrainian government
  eAid,

  /// "єВідновлення" card
  ///
  /// Account for war time aid money from the Ukrainian government
  rebuilding,

  /// Unknown card
  other;

  @override
  String toString() => name;
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

      case 'white':
        return CardType.white;

      case 'platinum':
        return CardType.platinum;

      case 'iron':
        return CardType.iron;

      case 'yellow':
        return CardType.yellow;

      case 'fop':
        return CardType.fop;

      case 'eAid':
        return CardType.eAid;

      case 'rebuilding':
        return CardType.rebuilding;

      default:
        return CardType.other;
    }
  }

  @override
  String toString() {
    return '$mask ($type)';
  }
}

/// Representation of clientInfo result
class Client {
  Client._fromJson(Map<String, dynamic> data, this.controller)
      : name = data['name'] as String,
        id = SendId(data['clientId'] as String, SendIdType.client),
        _webHookUrl =
            data['webHookUrl'] != null && (data['webHookUrl'] as String) != ''
                ? (Uri.tryParse(data['webHookUrl'] as String))
                : null,
        permissions = ClientPermission.parse(data['permissions'] as String) {
    jars.addAll(
      (data['jars'] as List<dynamic>? ?? <dynamic>[]).map(
        (dynamic e) => Jar._fromJson(e as Map<String, dynamic>, this),
      ),
    );

    final accountsData =
        List<Map<String, dynamic>>.from(data['accounts'] as Iterable<dynamic>);

    final list = accountsData.map((e) => Account._fromJson(e, this)).toList();

    if (sortAccounts) {
      const uahOrder = [
        CardType.black,
        CardType.white,
        CardType.yellow,
        CardType.fop,
        CardType.eAid,
        CardType.rebuilding,
      ];
      const curOrder = ['UAH', 'USD', 'EUR', 'PLN'];

      list.sort((a, b) => a.id.compareTo(b.id));

      List<Account> uah, known, unknown;
      uah = [];
      known = [];
      unknown = [];

      for (final e in list) {
        List<Account> arr;

        if (e.balance.currency.code == 'UAH') {
          arr = uah;
        } else {
          arr = (curOrder.contains(e.balance.currency.code) ? unknown : known);
        }

        arr.add(e);
      }

      uah.sort((a, b) {
        final indA = uahOrder.indexOf(a.type);
        final indB = uahOrder.indexOf(b.type);

        if (indA == -1 && indB == -1) {
          return 0;
        }
        if (indA == -1 && indB != -1) {
          return 1;
        }
        if (indA != -1 && indB == -1) {
          return -1;
        }

        if (indA < indB) {
          return -1;
        }
        if (indA > indB) {
          return 1;
        }
        return 0;
      });

      known.sort((a, b) {
        final indA = curOrder.indexOf(a.balance.currency.code);
        final indB = curOrder.indexOf(b.balance.currency.code);

        if (indA == -1 && indB == -1) {
          return 0;
        }
        if (indA == -1 && indB != -1) {
          return 1;
        }
        if (indA != -1 && indB == -1) {
          return -1;
        }

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
  final SendId id;

  /// Webhook URL
  ///
  /// Identifies if a webhook was set. Is null, if it wasn't
  Uri? get webHookUrl => _webHookUrl;

  Uri? _webHookUrl;

  /// Set new WebHook URL
  ///
  /// Throws [APIError] if it fails
  Future<bool> setWebHook(Uri url) async {
    await controller.call(
      APIRequest(
        'setWebHook',
        methodId: 'setWebHook',
        useAuth: true,
        httpMethod: APIHttpMethod.POST,
        data: {
          'webHookUrl': url.toString(),
        },
      ),
    );

    _webHookUrl = url;

    return true;
  }

  /// List of granted permissions
  ///
  /// See [ClientPermission]
  final Set<ClientPermission> permissions;

  /// List of jars in account
  ///
  /// See [Jar]
  final List<Jar> jars = [];

  /// List of available accounts
  ///
  /// Monobank API returns the accounts in
  /// different (and random) order every time
  ///
  /// For that, this library tries to sort
  /// the accounts to match the order in
  /// official monobank app
  ///
  /// If you don't need sort, see [sortAccounts]
  final List<Account> accounts = [];

  /// Parent of the client
  final API controller;

  @override
  String toString() {
    return '$name: ${id.id}';
  }

  /// Controls account sorting
  ///
  /// See [accounts]
  ///
  /// - `true`: enable sorting
  /// - `false`: disable sorting
  static bool sortAccounts = true;
}

/// Send ID
///
/// Identifies IDs that can be used to compose send.monobank.ua links
/// and provides a composer for them
class SendId {
  /// Construct a Send ID
  ///
  /// Type can be either [SendIdType.client] or [SendIdType.jar], which impacts
  /// the format of the link
  SendId(this.id, this.type);

  /// Url for the send.monobank.ua link
  ///
  /// Constructed from [id] and [type]
  Uri get url => Uri(
        scheme: 'https',
        host: 'send.monobank.ua',
        pathSegments: [
          if (type == SendIdType.jar) 'jar',
          id,
        ],
      );

  /// Send ID of the client or jar
  final String id;

  /// Type of the ID
  ///
  /// See [SendIdType]
  final SendIdType type;

  @override
  String toString() {
    return url.toString();
  }
}

/// Type of the Send ID
///
/// See [SendId]
enum SendIdType {
  /// The Send ID belongs to a personal account
  client,

  /// The Send ID is associated with a jar
  jar,
}

/// Client Permissions
///
/// Types of permissions
enum ClientPermission {
  /// Can see personal account info
  personalInfo('p'),

  /// Can see statement
  statement('s'),

  /// Can have access to the FOP account
  fop('f'),

  /// Can see jar list
  jars('j');

  /// Compose a permission by its code
  const ClientPermission(this.name);

  /// Permission literal
  final String name;

  /// Parse a permission string
  static Set<ClientPermission> parse(String str) {
    final set = <ClientPermission>{};

    for (final e in str.split('')) {
      if (e == 'p') {
        set.add(personalInfo);
      } else if (e == 's') {
        set.add(statement);
      } else if (e == 'f') {
        set.add(fop);
      } else if (e == 'j') {
        set.add(jars);
      }
    }

    return set;
  }
}

/// The jar
///
/// A jar is a personal account that can be used to save or collect money
class Jar {
  /// ID of the jar
  final String id;

  /// Send ID of the jar
  ///
  /// Can be used for send.monobank.ua links
  final SendId sendId;

  /// Name of the jar
  final String title;

  /// Description for the jar
  final String description;

  /// Balance of the jar
  final Money balance;

  /// Goal of the jar
  final Money? goal;

  /// Parent account
  final Client client;

  /// Check if the jar is full
  ///
  /// Returns `true` if the jar is full
  ///
  /// Always returns false is jar has no goal
  bool get isFull => goal == null ? true : balance >= goal!;

  @override
  String toString() {
    return '🍯 $title: $balance${goal == null ? '' : ' / $goal'}';
  }

  Jar._fromJson(Map<String, dynamic> data, this.client)
      : id = data['id'] as String,
        sendId = SendId(
          (data['sendId'] as String).substring(4),
          SendIdType.jar,
        ),
        title = data['title'] as String,
        description = data['description'] as String,
        balance = Money(
          data['balance'] as int,
          Currency.number(data['currencyCode'] as int),
        ),
        goal = data['goal'] == null
            ? null
            : Money(
                data['goal'] as int,
                Currency.number(data['currencyCode'] as int),
              );
}

/// Cashback type
enum CashbackType {
  /// Cashback is not available
  none,

  /// Cashback is in Hryvnia
  uah,

  /// Cashback is in miles
  miles,

  /// Cashback is unknown
  unknown;

  /// Parse a string to [CashbackType]
  static CashbackType fromString(String? str) {
    if (str == 'None' || str == '' || str == null) {
      return none;
    } else if (str == 'UAH') {
      return uah;
    } else if (str == 'Miles') {
      return miles;
    } else {
      return unknown;
    }
  }
}

/// Representation of cashback
class Cashback {
  Cashback._(this.amount, this.type);

  /// Amount of cashback
  final double amount;

  /// String representation of cashback type
  final CashbackType type;

  /// Related object to the Cashback
  ///
  /// double amount, if not overridden
  dynamic get object => amount;

  @override
  String toString() => '🎁 $amount';
}

/// Account doesn't provide cashback
class NoCashback extends Cashback {
  NoCashback._() : super._(0, CashbackType.none);
  @override
  String toString() => '';
}

/// Account provides money-backed cashback
class MoneyCashback extends Cashback {
  MoneyCashback._(int amount, this.currency)
      : super._(amount.toDouble(), CashbackType.uah);

  /// The currency of cashback
  Currency currency;

  @override
  Money get object => Money(amount.floor(), currency);

  @override
  String toString() => '💰 ${object.toString()}';
}

/// Account provides miles cashback
class MilesCashback extends Cashback {
  MilesCashback._(int amount) : super._(amount / 100, CashbackType.miles);

  @override
  String toString() => '✈ ${amount}mi';
}

Cashback _cashback(int amount, CashbackType type) {
  switch (type) {
    case CashbackType.uah:
      return MoneyCashback._(amount, Currency.number(980));
    case CashbackType.miles:
      return MilesCashback._(amount);
    case CashbackType.none:
      return NoCashback._();
    default:
      return Cashback._(amount.toDouble(), CashbackType.unknown);
  }
}

/// Single item from statement
class StatementItem {
  StatementItem._fromJson(Map<String, dynamic> data, this.account)
      : id = data['id'] as String,
        time =
            DateTime.fromMillisecondsSinceEpoch((data['time'] as int) * 1000),
        description = data['description'] as String? ?? '',
        mcc = MCC(data['mcc'] as int),
        originalMcc = MCC(data['originalMcc'] as int),
        amount = account.balance.currency == Currency.dummy &&
                data['operationAmount'] as int == data['amount'] as int
            ? Money(
                data['operationAmount'] as int,
                Currency.number(data['currencyCode'] as int),
              )
            : Money(data['amount'] as int, account.balance.currency),
        operationAmount = Money(
          data['operationAmount'] as int,
          Currency.number(data['currencyCode'] as int),
        ),
        commissionRate = Money(
          data['commissionRate'] as int,
          Currency.number(data['currencyCode'] as int),
        ),
        cashback =
            _cashback(data['cashbackAmount'] as int, account.cashbackType),
        balance = Money(
          data['balance'] as int,
          account.balance.currency,
        ),
        comment = data['comment'] as String? ?? '',
        hold = data['hold'] as bool,
        receiptId = data['receiptId'] as String?,
        invoiceId = data['invoiceId'] as String?,
        counterEdrpou = data['counterEdrpou'] as String?,
        counterIban = data['counterIban'] as String?,
        counterName = data['counterName'] as String?;

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

  /// Pure transaction MCC code
  final MCC originalMcc;

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

  /// Check number for check.gov.ua
  final String? receiptId;

  /// Invoice number for FOP account transactions
  final String? invoiceId;

  /// Counteragent Edrpou number, is available only for accounts with `fop` type
  final String? counterEdrpou;

  /// Counteragent Iban number, is available only for accounts with `fop` type
  final String? counterIban;

  /// Counteragent name, is available only for accounts with `fop` type
  final String? counterName;

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

      final f = (lFrom.millisecondsSinceEpoch / 1000).floor();
      final t = (lTo.millisecondsSinceEpoch / 1000).floor();

      APIResponse data;
      List<Map<String, dynamic>> body;

      try {
        data = await account.client.controller.call(APIRequest(
          'personal/statement/${account.id}/$f/$t',
          methodId: 'personal/statement',
          useAuth: true,
        ));

        body = List<Map<String, dynamic>>.from(data.body as Iterable<dynamic>);
      } catch (e) {
        if (!ignoreErrors) rethrow;
        body = [];
      }

      final i = (reverse ? body : body.reversed)
          .map((e) => StatementItem._fromJson(e, account));

      for (final e in i) {
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
      : id = data['id'] as String,
        accountBalance = Money(data['balance'] as int,
            Currency.number(data['currencyCode'] as int)),
        creditLimit = Money(data['creditLimit'] as int,
            Currency.number(data['currencyCode'] as int)),
        cashbackType = CashbackType.fromString(data['cashbackType'] as String?),
        iban = data['iban'] as String,
        sendId = data['sendId'] as String != ''
            ? SendId(data['sendId'] as String, SendIdType.client)
            : null,
        type = BankCard.cardTypeFromString(data['type'] as String),
        cards = List<String>.from(data['maskedPan'] as Iterable<dynamic>)
            .map((e) => BankCard._(
                  Mask._fromString(e),
                  BankCard.cardTypeFromString(data['type'] as String),
                ))
            .toList();

  /// Account ID
  ///
  /// Actually can be used for getting statement only
  final String id;

  /// Account Send ID
  ///
  /// Can be used to generate send.monobank.ua links
  final SendId? sendId;

  /// Parent
  final Client client;

  /// Reported account balance (including credit limit)
  final Money accountBalance;

  /// Credit limit
  final Money creditLimit;

  /// Cashback type
  final CashbackType cashbackType;

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

  @override
  String toString() {
    return '$id: $balance';
  }
}

/// Interface for webhook event types
///
/// See the only available type [StatementItemWebhookEvent]
class WebhookEvent {
  /// Parse an event from JSON
  ///
  /// Throws [WebhookEventParseException] if parsing fails
  factory WebhookEvent.fromJson(Map<String, dynamic> data) {
    switch (data['type'] as String) {
      case 'StatementItem':
        return StatementItemWebhookEvent._fromJson(data);
      default:
        throw Exception('Unknown webhook event type: ${data['type']}');
    }
  }
}

/// Transaction webhook event
class StatementItemWebhookEvent implements WebhookEvent {
  /// Account referenced in the webhook event.
  ///
  /// Despite the fact [LazyAccount] implements [Account], most of getters are
  /// stubs. See [LazyAccount] for details. To get actual account data, use
  /// [LazyAccount.resolve].
  final LazyAccount account;

  /// Statement item referenced in the webhook event.
  ///
  /// Almost full data is available, but not all of it, particularly, things like
  /// cashback type and other data that's not available in the Statement Item
  /// object in API and is usually delivered from the [Account] object by
  /// [StatementItem]'s internal logic.
  ///
  /// If you want to access proper data, call [LazyAccount.resolve] on
  /// [account] and then use [LazyStatementItem.regenerate].
  late final LazyStatementItem item;

  StatementItemWebhookEvent._fromJson(Map<String, dynamic> data)
      : account = LazyAccount(
          (data['data'] as Map<String, dynamic>)['account'] as String,
        ) {
    item = LazyStatementItem._fromJson(
      (data['data'] as Map<String, dynamic>)['statementItem']
          as Map<String, dynamic>,
      account,
    );
  }
}

/// Represents an unresolved account
///
/// Use [resolve] method to get resolved account
///
/// All implemented properties are stubs, except [id] - which contains an actual
/// ID, and [client] - which throws exception if not resolved.
class LazyAccount implements Account {
  @override
  final String id;

  /// Create an unresolved account
  ///
  /// You can use this constructor to create unresolved account.
  LazyAccount(this.id);

  /// Resolve account
  ///
  /// Returns resolved account or null if account is not found. Current instance
  /// turns into a proxy for the resolved instance.
  ///
  /// You need to provide [client] with [PersonalMethods] mixin support
  /// (e.g. [MonoAPI] to resolve account.
  Future<Account?> resolve(PersonalMethods client) async {
    final e = await client.clientInfo();

    for (final a in e.accounts) {
      if (a.id == id) {
        originalAccount = a;
        return a;
      }
    }

    return null;
  }

  /// Resolved instance of account
  ///
  /// See [resolve]
  Account? originalAccount;

  @override
  Money get accountBalance =>
      originalAccount?.accountBalance ?? Money(0, Currency.dummy);

  @override
  Money get balance => originalAccount?.balance ?? Money(0, Currency.dummy);

  @override
  List<BankCard> get cards => originalAccount?.cards ?? [];

  @override
  CashbackType get cashbackType =>
      originalAccount?.cashbackType ?? CashbackType.unknown;

  @override
  Client get client => originalAccount?.client ?? (throw UnimplementedError());

  @override
  Money get creditLimit =>
      originalAccount?.creditLimit ?? Money(0, Currency.dummy);

  @override
  String get iban => originalAccount?.iban ?? '';

  @override
  bool get isCreditUsed => originalAccount?.isCreditUsed ?? false;

  @override
  bool get isOverdraft => originalAccount?.isOverdraft ?? false;

  @override
  Money get pureBalance =>
      originalAccount?.pureBalance ?? Money(0, Currency.dummy);

  @override
  SendId? get sendId => originalAccount?.sendId;

  @override
  Statement statement(DateTime from, DateTime to) =>
      originalAccount?.statement(from, to) ?? Statement._(this, from, to);

  @override
  CardType get type => originalAccount?.type ?? CardType.other;
}

/// Represents a lazy statement item
///
/// The difference between this class and [StatementItem] is that this class
/// stores the raw data used to generate the instance, so you can regenerate
/// it any time if the [account] state changes.
///
/// This class is mainly designed to work in pair with [LazyAccount] class.
class LazyStatementItem extends StatementItem {
  final Map<String, dynamic> _data;

  /// Regenerate the instance from raw data. This method is called when
  /// the [account] state changes. For example. when you call [LazyAccount.resolve].
  StatementItem regenerate() => StatementItem._fromJson(_data, account);

  LazyStatementItem._fromJson(this._data, Account account)
      : super._fromJson(_data, account);
}

/// Enable personal/* methods
///
/// Gives access to Client, Account and Statement objects
mixin PersonalMethods on API {
  /// Request Client object
  Future<Client> clientInfo() async {
    final data = await call(APIRequest(
      'personal/client-info',
      methodId: 'personal/client-info',
      useAuth: true,
    ));
    return Client._fromJson(data.body as Map<String, dynamic>, this);
  }
}

/// Enable bank/currency method
mixin CurrencyMethods on API {
  /// Get currencies
  ///
  /// Generates CurrencyInfo's from
  /// monobank currency dataF
  Future<Iterable<CurrencyInfo>> currency({bool burst = false}) async {
    final data = await call(APIRequest(
      'bank/currency',
      methodId: 'bank/currency',
      settings: (burst ? APIFlags.waiting | APIFlags.skip : APIFlags.waiting),
    ));
    final curs =
        List<Map<String, dynamic>>.from(data.body as Iterable<dynamic>);
    return curs.map<CurrencyInfo>((e) => CurrencyInfo(
          Currency.number(e['currencyCodeA'] as int),
          Currency.number(e['currencyCodeB'] as int),
          double.parse(
            (e.containsKey('rateCross') ? e['rateCross'] : e['rateSell'])
                .toString(),
          ),
          double.parse(
            (e.containsKey('rateCross') ? e['rateCross'] : e['rateBuy'])
                .toString(),
          ),
          DateTime.fromMillisecondsSinceEpoch(
            (e['date'] as int) * 1000,
            isUtc: true,
          ),
        ));
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
