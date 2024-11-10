import 'package:monobank_api/mcc.dart';
import 'package:monobank_api/monobank_api.dart';

/// Default library domain that's being used
const String _monoPureDomain = 'https://api.monobank.ua/';

/// Card number
///
/// Whole card number is unknown, but starting and ending numbers are
class Mask {
  /// Construct a card mask
  ///
  /// [start] - few first numbers
  /// [end] - few last numbers
  Mask(this.start, this.end);

  /// Few first numbers
  final String start;

  /// Few last numbers
  final String end;

  /// Parse a mask from string
  ///
  /// Format: `start*end`
  factory Mask.fromString(String s) {
    final e = s.split('*');
    return Mask(e.first, e.last);
  }

  @override
  String toString() => '$start****$end';
}

/// Card type class
///
/// This class is a container for [CardType] to also store raw data
/// so unknown card types can be identified
class CardTypeClass {
  /// Construct a card type class
  ///
  /// [knownType] - known card type enum
  /// [raw] - raw card type string
  CardTypeClass(this.knownType, this.raw);

  /// Card type enum
  final CardType knownType;

  /// Raw card type string
  final String? raw;

  @override
  String toString() => raw ?? '';

  /// Comparison operator
  ///
  /// Can compare with [CardTypeClass], [CardType] and [String]
  @override
  bool operator ==(Object other) {
    if (other is CardTypeClass) {
      return raw == other.raw;
    }

    if (other is CardType) {
      return knownType == other;
    }

    if (other is String) {
      return raw == other;
    }

    return false;
  }

  @override
  int get hashCode => raw.hashCode;
}

/// Card type enum
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

  /// "Зроблено в Україні" card
  ///
  /// Account for national cashback program
  madeInUkraine,

  /// Unknown card
  other;

  @override
  String toString() => name;
}

/// Representation of a bank card
///
/// Contains info about account type and known card numbers
class BankCard {
  /// Construct a bank card
  BankCard(this.mask, this.type);

  /// See [Mask]
  Mask mask;

  /// See [CardTypeClass]
  CardTypeClass type;

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

      case 'madeInUkraine':
        return CardType.madeInUkraine;

      default:
        return CardType.other;
    }
  }

  @override
  String toString() {
    return '$mask ($type)';
  }

  /// Check if the card is Mastercard
  bool isMastercard() {
    if (mask.start.startsWith('5')) {
      return true;
    }

    if (mask.start.length >= 4) {
      final start = int.tryParse(mask.start.substring(0, 4));
      if (start == null) return false;
      return start >= 2221 && start <= 2720;
    }

    return false;
  }

  /// Check if the card is Visa
  bool isVisa() {
    return mask.start.startsWith('4');
  }
}

/// Representation of clientInfo result
class Client {
  /// Construct a client
  ///
  /// [data] - data from the API
  /// [controller] - parent API controller
  Client.fromJson(Map<String, dynamic> data, this.controller)
      : name = data['name'] as String,
        id = SendId(data['clientId'] as String, SendIdType.client),
        _webHookUrl =
            data['webHookUrl'] != null && (data['webHookUrl'] as String) != ''
                ? (Uri.tryParse(data['webHookUrl'] as String))
                : null,
        permissions = ClientPermission.parse(data['permissions'] as String) {
    jars.addAll(
      (data['jars'] as List<dynamic>? ?? <dynamic>[]).map(
        (dynamic e) => Jar.fromJson(e as Map<String, dynamic>, this),
      ),
    );

    final accountsData =
        List<Map<String, dynamic>>.from(data['accounts'] as Iterable<dynamic>);

    final list = accountsData.map((e) => Account.fromJson(e, this)).toList();

    if (sortAccounts) {
      const uahOrder = [
        CardType.black,
        CardType.white,
        CardType.yellow,
        CardType.fop,
        CardType.eAid,
        CardType.rebuilding,
        CardType.madeInUkraine,
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
        final indA = uahOrder.indexOf(a.type.knownType);
        final indB = uahOrder.indexOf(b.type.knownType);

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

  /// Convert client to JSON
  Map<String, dynamic> toJson() => {
        'clientId': id.id,
        'name': name,
        'webHookUrl': _webHookUrl?.toString(),
        'permissions': permissions.map((e) => e.name).join(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'jars': jars.map((e) => e.toJson()).toList(),
      };

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

/// Statement source interface
///
/// This interface is used to provide a common interface for accounts and jars
/// to be used when processing statement items.
///
/// You can access specific account or jar properties by casting the source to
/// [Account] or [Jar] respectively.
abstract class StatementSource {
  /// ID of the source
  String get id;

  /// Parent client
  Client get client;

  /// Balance
  Money get balance;

  /// Cashback type
  CashbackType get cashbackType;

  /// Get statement object for current account.
  ///
  /// [from] - past, [to] - future
  ///
  /// See [Statement] for more details
  Statement statement(DateTime from, DateTime to) {
    return Statement(this, from, to);
  }
}

/// Lazy statement source
///
/// This class is yielded in webhooks, which don't provide full account info.
///
/// See [LazyStatementSource.resolve] and [LazyStatementSource.resolveFromClient]
/// to resolve the source into a proper [Account] or [Jar] object.
///
/// All implemented properties are stubs, except id - which contains an actual ID,
/// and client - which throws exception if not resolved.
///
/// If you request statement on an unresolved source, you will get incomplete data
/// in fields that rely on the original source, like [StatementItem.cashback],
/// [amount] and [balance].
class LazyStatementSource extends StatementSource {
  /// Construct a lazy statement source
  LazyStatementSource(this.id);

  @override
  final String id;

  StatementSource? _originalSource;

  /// Check if the source is resolved
  ///
  /// Returns `true` if the source is resolved
  bool get isResolved => _originalSource != null;

  /// Get the original source
  ///
  /// Returns null if the source is not resolved
  StatementSource? get originalSource {
    return _originalSource;
  }

  /// Get Client object used in statement
  ///
  /// Throws [StateError] if the original source is not resolved
  @override
  Client get client {
    if (_originalSource == null) {
      throw StateError('Original source is not resolved');
    }

    return _originalSource!.client;
  }

  @override
  Money get balance => _originalSource?.balance ?? Money(0, Currency.dummy);

  @override
  CashbackType get cashbackType =>
      _originalSource?.cashbackType ?? CashbackType.unknown;

  @override
  @Deprecated('Calling this method on unresolved source will return incomplete'
      ' data. Resolve this source into a proper Account or Jar object with'
      ' resolveFromClient or resolve method.')
  Statement statement(DateTime from, DateTime to) {
    return super.statement(from, to);
  }

  /// Resolve the source
  ///
  /// [api] - MonoAPI instance to resolve the source
  ///
  /// Returns the resolved source. Current instance becomes a proxy
  /// to the resolved source.
  ///
  /// It may resolve to either [Account] or [Jar] object, or null if the source
  /// is not found. You can cast the result to [Account] or [Jar] to access
  /// specific properties.
  ///
  /// Alternatively, you can use [resolveFromClient] to set the client instance directly
  /// if you already have it.
  Future<StatementSource?> resolve(PersonalMethods api) async {
    final e = await api.clientInfo();

    return await resolveFromClient(e);
  }

  /// Set client instance directly
  ///
  /// Useful when you already have the client instance
  ///
  /// It may resolve to either [Account] or [Jar] object, or null if the source
  /// is not found. You can cast the result to [Account] or [Jar] to access
  /// specific properties.
  ///
  /// Alternatively, you can use [resolve] to resolve the Client from MonoAPI
  /// instance
  Future<StatementSource?> resolveFromClient(Client client) async {
    for (final a in client.accounts) {
      if (a.id == id) {
        _originalSource = a;
        return a;
      }
    }

    for (final j in client.jars) {
      if (j.id == id) {
        _originalSource = j;
        return j;
      }
    }

    return null;
  }
}

/// The jar
///
/// A jar is a personal account that can be used to save or collect money
class Jar extends StatementSource {
  /// ID of the jar
  @override
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
  @override
  final Money balance;

  /// Goal of the jar
  final Money? goal;

  /// Parent account
  @override
  final Client client;

  @override
  CashbackType get cashbackType => CashbackType.none;

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

  /// Construct a jar
  ///
  /// [data] - data from the API
  /// [client] - parent API client
  Jar.fromJson(Map<String, dynamic> data, this.client)
      : id = data['id'] as String,
        sendId = SendId(
          (data['sendId'] as String? ?? '').replaceFirst('jar/', ''),
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

  /// Convert jar to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'sendId': sendId.id,
        'title': title,
        'description': description,
        'currencyCode': balance.currency.code,
        'balance': balance.amount,
        'goal': goal?.amount,
      };
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

  @override
  String toString() {
    switch (this) {
      case none:
        return 'None';
      case uah:
        return 'UAH';
      case miles:
        return 'Miles';
      case unknown:
        return 'Unknown';
    }
  }
}

/// Representation of cashback
class Cashback {
  /// Construct cashback object
  ///
  /// [amount] - amount of cashback
  /// [type] - type of cashback
  Cashback(this.amount, this.type);

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

  /// Parse cashback from type and amount
  ///
  /// [amount] - amount of cashback
  /// [type] - type of cashback
  factory Cashback.fromType(int amount, CashbackType type) {
    switch (type) {
      case CashbackType.uah:
        return MoneyCashback(amount, Currency.number(980));
      case CashbackType.miles:
        return MilesCashback(amount);
      case CashbackType.none:
        return NoCashback();
      default:
        return Cashback(amount.toDouble(), CashbackType.unknown);
    }
  }
}

/// Account doesn't provide cashback
class NoCashback extends Cashback {
  /// Construct a NoCashback object
  ///
  /// This object is used when the account doesn't provide cashback
  NoCashback() : super(0, CashbackType.none);
  @override
  String toString() => '';
}

/// Account provides money-backed cashback
class MoneyCashback extends Cashback {
  /// Construct a MoneyCashback object
  ///
  /// [amount] - amount of cashback
  /// [currency] - currency of cashback
  MoneyCashback(int amount, this.currency)
      : super(amount.toDouble(), CashbackType.uah);

  /// The currency of cashback
  Currency currency;

  @override
  Money get object => Money(amount.floor(), currency);

  @override
  String toString() => '💰 ${object.toString()}';
}

/// Account provides miles cashback
class MilesCashback extends Cashback {
  /// Construct a MilesCashback object
  ///
  /// The API returns miles * 100, so the amount is divided by 100
  MilesCashback(int amount) : super(amount / 100, CashbackType.miles);

  @override
  String toString() => '✈ ${amount}mi';
}

/// Single item from statement
class StatementItem {
  /// Construct a statement item
  ///
  /// [data] - data from the API
  /// [account] - parent account
  StatementItem.fromJson(Map<String, dynamic> data, this.account)
      : isServiceMessage = false,
        serviceMessageCode = null,
        id = data['id'] as String,
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
        cashback = Cashback.fromType(
          data['cashbackAmount'] as int,
          account.cashbackType,
        ),
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

  /// Construct a service message
  ///
  /// Service messages are injected into the statement stream
  /// by the library to inform about possible issues with the data
  ///
  /// [serviceMessageCode] - service message code
  /// [description] - description of the message
  /// [account] - parent account
  StatementItem.serviceMessage(
      this.serviceMessageCode, this.description, this.account,
      {DateTime? time})
      : isServiceMessage = true,
        id = '',
        time = time ?? DateTime.now(),
        mcc = MCC(0),
        originalMcc = MCC(0),
        amount = Money(0, Currency.dummy),
        operationAmount = Money(0, Currency.dummy),
        commissionRate = Money(0, Currency.dummy),
        cashback = NoCashback(),
        balance = Money(0, Currency.dummy),
        comment = '',
        hold = false,
        receiptId = null,
        invoiceId = null,
        counterEdrpou = null,
        counterIban = null,
        counterName = null;

  /// Construct a statement item to json
  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.millisecondsSinceEpoch ~/ 1000,
        'description': description,
        'mcc': mcc.code,
        'originalMcc': originalMcc.code,
        'hold': hold,
        'amount': amount.amount,
        'operationAmount': operationAmount.amount,
        'commissionRate': commissionRate.amount,
        'cashbackAmount': cashback.amount,
        'balance': balance.amount,
        'comment': comment,
        'receiptId': receiptId,
        'invoiceId': invoiceId,
        'counterEdrpou': counterEdrpou,
        'counterIban': counterIban,
        'counterName': counterName,
      };

  /// Parent account
  final StatementSource account;

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

  /// True if the transaction is a service message and
  /// not a real transaction
  final bool isServiceMessage;

  /// Service message numeric code
  final StatementItemServiceMessageCode? serviceMessageCode;

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
/// Use [list] method to access statement.
///
/// Timestamps are inclusive.
class Statement {
  /// Construct a statement
  ///
  /// [account] - account to get statement from
  /// [from] - start from
  /// [to] - end on
  ///
  /// Timestamps are inclusive
  Statement(this.account, this.from, this.to);

  /// Source account
  final StatementSource account;

  /// Start from, past
  final DateTime from;

  /// End on, future
  final DateTime to;

  /// Maximum range for a single request
  ///
  /// This is a limit of the Monobank API, this value is used to
  /// determine where to split the statement request if the range
  /// is bigger than this value
  static Duration maxRequestRange = Duration(days: 31, hours: 1);

  /// Maximum possible items in a response
  ///
  /// This is a limit of the Monobank API, this value is used to
  /// determine if the library should start querying the statement
  /// in smaller parts to guarantee the correct order of transactions
  static int maxPossibleItems = 500;

  /// Begins stream of statement
  ///
  /// Items are being delivered as fast as possible if specified
  /// range is bigger than the one allowed by API
  ///
  /// In such case statement is being requested by parts
  ///
  /// **NOTE:** Monobank Statement API is designed for reverse chronological order
  /// first, if you request the statement in the chronological order, in cases
  /// when there will be more than [maxPossibleItems] transactions within a time
  /// frame the library will start buffering the transactions until the library
  /// can guarantee that the transactions are in the correct order.
  Stream<StatementItem> list({
    /// Reverse stream
    ///
    /// `false`: from older to newer
    /// `true`: from newer to older
    bool isReverseChronological = true,

    /// Include service messages
    ///
    /// The library will include service messages in the stream
    /// to inform about possible missing data and other issues.
    ///
    /// See [StatementItem.isServiceMessage] and
    /// [StatementItem.serviceMessageCode]
    ///
    /// `false`: exclude service messages
    /// `true`: include service messages
    bool includeServiceMessages = true,

    /// Abort controller
    ///
    /// Allows to cancel the request in the middle of the process
    AbortController? abortController,
  }) async* {
    if (isReverseChronological) {
      DateTime localFrom = from;
      DateTime localTo = to;
      String? lastId;

      while (abortController?.isCancelled != true) {
        localFrom = localTo.subtract(maxRequestRange);
        if (localFrom.isBefore(from)) localFrom = from;

        final result = await _requestRange(localFrom, localTo, abortController);

        final body =
            List<Map<String, dynamic>>.from(result.body as Iterable<dynamic>);
        List<StatementItem> statementFragment =
            body.map((e) => StatementItem.fromJson(e, account)).toList();

        final lastItem =
            statementFragment.isEmpty ? null : statementFragment.last;

        // When making repeat requests with precision to the second to
        // fit within the maxPossibleItems limit, server might return
        // the same transactions again, so we need to skip them
        if (lastId != null) {
          final repeatIndex =
              statementFragment.indexWhere((e) => e.id == lastId);

          if (repeatIndex != -1) {
            statementFragment = statementFragment.sublist(repeatIndex + 1);
          }
        }

        for (final e in statementFragment) {
          yield e;
          lastId = e.id;
        }

        final isDeadEnd = body.length >= maxPossibleItems &&
            ((lastItem != null && lastItem.time == localTo) ||
                localFrom == localTo);

        if (includeServiceMessages && isDeadEnd) {
          yield StatementItem.serviceMessage(
            StatementItemServiceMessageCode.possibleMissingData,
            'Statement might contain missing data because request for '
            'the given second returns more than $maxPossibleItems items',
            account,
            time: localFrom,
          );
        }

        if (body.length >= maxPossibleItems) {
          if (!isDeadEnd && lastItem != null) {
            localTo = lastItem.time;
          } else {
            localTo = localTo.subtract(Duration(seconds: 1));

            if (localTo.isBefore(from) || localTo == from) {
              break;
            }
          }
        } else if (localFrom == from) {
          // We reached the target from value and returned items number
          // is less than maxPossibleItems, so we can stop
          break;
        } else {
          // We can continue fetching data
          localTo = localFrom.subtract(Duration(seconds: 1));
        }
      }
    } else {
      DateTime localFrom = from;
      DateTime localTo = to;

      while (abortController?.isCancelled != true) {
        localTo = localFrom.add(maxRequestRange);
        if (localTo.isAfter(to)) localTo = to;

        final buffer = <StatementItem>[];
        final subStatement = account.statement(localFrom, localTo);

        await for (final item in subStatement.list(
          isReverseChronological: true,
          includeServiceMessages: includeServiceMessages,
          abortController: abortController,
        )) {
          buffer.add(item);
        }

        // Yield buffered items in the chronological order
        for (final e in buffer.reversed) {
          yield e;
        }

        // If we reached the target to value, we can stop
        if (localTo == to) {
          break;
        }

        // Proceed to the next range in the chronological order
        localFrom = localTo.add(Duration(seconds: 1));
      }
    }
  }

  Future<APIResponse> _requestRange(
    DateTime from,
    DateTime to,
    AbortController? abortController,
  ) {
    final f = from.millisecondsSinceEpoch ~/ 1000;
    final t = to.millisecondsSinceEpoch ~/ 1000;

    return account.client.controller.call(APIRequest(
      'personal/statement/${account.id}/$f/$t',
      methodId: 'personal/statement',
      useAuth: true,
      abortController: abortController,
    ));
  }
}

/// Statement Item Service Message Code
///
/// Codes for service messages in statement items
enum StatementItemServiceMessageCode {
  /// Not a service message
  none,

  /// Unknown service message
  unknown,

  /// Statement might contain missing data because request for the given
  /// second returns more than [Statement.maxPossibleItems] items
  possibleMissingData,
}

/// Represents monobank account (balance)
class Account extends StatementSource {
  /// Extracts credit limit from account balance for [balance] getter
  /// to show true account balance
  ///
  /// You can also use [pureBalance] instead
  static bool hideCreditLimit = false;

  /// Construct an account
  ///
  /// [data] - data from the API
  /// [client] - parent client
  Account.fromJson(Map<String, dynamic> data, this.client)
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
        type = CardTypeClass(
          BankCard.cardTypeFromString(data['type'] as String),
          data['type'] as String,
        ),
        cards = List<String>.from(data['maskedPan'] as Iterable<dynamic>)
            .map((e) => BankCard(
                  Mask.fromString(e),
                  CardTypeClass(
                    BankCard.cardTypeFromString(data['type'] as String),
                    data['type'] as String,
                  ),
                ))
            .toList();

  /// Convert account to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'sendId': sendId?.id ?? '',
        'balance': accountBalance.amount,
        'creditLimit': creditLimit.amount,
        'type': type.raw,
        'currencyCode': accountBalance.currency.code,
        'cashbackType': cashbackType.toString(),
        'maskedPan':
            cards.map((e) => '${e.mask.start}****${e.mask.end}').toList(),
        'iban': iban,
      };

  /// Account ID
  ///
  /// Actually can be used for getting statement only
  @override
  final String id;

  /// Account Send ID
  ///
  /// Can be used to generate send.monobank.ua links
  final SendId? sendId;

  /// Parent
  @override
  final Client client;

  /// Reported account balance (including credit limit)
  final Money accountBalance;

  /// Credit limit
  final Money creditLimit;

  /// Cashback type
  @override
  final CashbackType cashbackType;

  /// IBAN
  final String iban;

  /// List of related cards
  final List<BankCard> cards;

  /// Account type
  ///
  /// See [CardTypeClass]
  final CardTypeClass type;

  /// Account balance without credit funds
  Money get pureBalance => (accountBalance - creditLimit);

  /// Account balance
  ///
  /// Returns accountBalance or pureBalance
  /// depending on [hideCreditLimit] flag
  @override
  Money get balance => (hideCreditLimit ? pureBalance : accountBalance);

  /// Returns true when the account is in actual overdraft
  ///
  /// This means balance owes more than balance
  /// and credit limit combined
  bool get isOverdraft => accountBalance.isNegative;

  /// Returns true when credit funds are being used or the account
  /// is in overdraft
  bool get isCreditUsed => accountBalance < creditLimit;

  @override
  String toString() {
    return '$id: $balance';
  }
}

/// Interface for webhook event types
///
/// See the only available type [StatementItemWebhookEvent]
abstract class WebhookEvent {
  /// Parse an event from JSON
  ///
  /// Throws [WebhookEventParseException] if parsing fails
  factory WebhookEvent.fromJson(Map<String, dynamic> data) {
    switch (data['type'] as String) {
      case 'StatementItem':
        return StatementItemWebhookEvent.fromJson(data);
      default:
        throw Exception('Unknown webhook event type: ${data['type']}');
    }
  }

  /// Convert event to JSON
  Map<String, dynamic> toJson();
}

/// Transaction webhook event
class StatementItemWebhookEvent implements WebhookEvent {
  /// Account referenced in the webhook event.
  ///
  /// Despite the fact [LazyStatementSource] implements [StatementSource], most of
  /// getters are stubs. See [LazyStatementSource] for details. To get actual account
  /// data, use [LazyStatementSource.resolve].
  final LazyStatementSource account;

  /// Statement item referenced in the webhook event.
  ///
  /// Almost full data is available, but not all of it, particularly, things like
  /// cashback type and other data that's not available in the Statement Item
  /// object in API and is usually delivered from the [Account] object by
  /// [StatementItem]'s internal logic.
  ///
  /// If you want to access proper data, call [LazyStatementSource.resolve] on
  /// [account] and then use [LazyStatementItem.regenerate].
  late final LazyStatementItem item;

  /// Construct a webhook event
  ///
  /// [data] - data from the API
  StatementItemWebhookEvent.fromJson(Map<String, dynamic> data)
      : account = LazyStatementSource(
          (data['data'] as Map<String, dynamic>)['account'] as String,
        ) {
    item = LazyStatementItem.fromJson(
      (data['data'] as Map<String, dynamic>)['statementItem']
          as Map<String, dynamic>,
      account,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'StatementItem',
        'data': {
          'account': account.id,
          'statementItem': item.toJson(),
        },
      };
}

/// Represents a lazy statement item
///
/// The difference between this class and [StatementItem] is that this class
/// stores the raw data used to generate the instance, so you can regenerate
/// it any time if the [account] state changes.
///
/// This class is mainly designed to work in pair with [LazyStatementSource] class.
class LazyStatementItem extends StatementItem {
  final Map<String, dynamic> _data;

  /// Regenerate the instance from raw data. This method is called when
  /// the [account] state changes. For example. when you call
  /// [LazyStatementSource.resolve].
  StatementItem regenerate() => StatementItem.fromJson(_data, account);

  /// Construct a lazy statement item
  ///
  /// [data] - raw data from the API
  /// [account] - parent account
  LazyStatementItem.fromJson(this._data, StatementSource account)
      : super.fromJson(_data, account);

  @override
  @Deprecated('This getter may return dummy currency if the account is not'
      ' resolved and operationAmount is not equal to amount, because account\'s'
      ' currency is unknown')
  Money get amount {
    return super.amount;
  }

  @override
  @Deprecated('This getter will return dummy currency if the account is not'
      ' resolved, because account\'s currency is unknown')
  Money get balance {
    return super.balance;
  }

  @override
  @Deprecated('This getter will always return Unknown cashback type if the'
      ' account is not resolved')
  Cashback get cashback {
    return super.cashback;
  }

  @override
  Map<String, dynamic> toJson() => _data;
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
    return Client.fromJson(data.body as Map<String, dynamic>, this);
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
