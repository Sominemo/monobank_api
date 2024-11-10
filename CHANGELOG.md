## 3.0.0

### Breaking Changes

-   All mentions of `Account` in statement-related classes were replaced
    with `StatementSource`
-   `BankCard.type` and `Account.type` are now a `CardTypeClass`
    instance instead of a `CardType` enum
-   In `Statement.list`, `reverse` parameter was renamed to `isReverseChronological`
    and now defaults to `true`
-   In `Statement.list`, `ignoreErrors` parameter was removed
-   The statement stream may now include service messages, notifying about possible
    discrepancies in the data. Right now such messages may be yielded when response length
    equals `maxPossibleItems` and the requested time range can't be smaller. This means
    some data might get truncated in the requested time range. You can check for
    service messages using `StatementItem.isServiceMessage`. You can also
    set `ignoreServiceMessages` to `true`.
-   `CashbackType.toString` now returns the same kind of string as API returns
    instead of enum name
-   `LazyAccount` was replaced with `LazyStatementSource`, the class was completely
    removed. The change also impacts `LazyStatementItem` class. You can cast the
    result of the `LazyStatementSource.resolve` method to `Account` or `Jar` to
    get specific fields.

### What's New

-   `Account` and `Jar` are now subclasses of `StatementSource`,
    this allows to fetch statements from jars too now using `StatementSource.statement`
-   Added support for `madeInUkraine` card type
-   Added access to raw card type string in `BankCard.type.raw`
-   Exposed `lastRequestsTimes` and `globalLastRequestTime` in API class
    to allow for state restoration and notifying the user about rate limits
-   Added fields and data types related to service messages in statement items
-   Added `AbortController` class to API to allow for cancelling requests.
    If the request is still in the cart, it will not be sent to the server
    when its turn comes. `APIError` with code 3 will be thrown as a response.
-   Added support for `AbortController` in `APIRequest`
-   Added `abortController` argument to `Statement.list`
-   Added methods `BankCard.isMastercard` and `BankCard.isVisa`
-   Made most of constructors in mono library public, including `fromJSON`,
    to support persistence
-   Added `toJSON()` methods to many classes in mono library for persistence
    support
-   `APIError` now has a new type - `isCancelled`, triggered when the request
    was cancelled using `AbortController`
-   Added `Cashback.fromType` factory
-   Added `StatementItemServiceMessageCode` enum to distinguish between different
    service message types

### What's Changed

-   Rewritten `Statement.list` to handle cases when more than maxPossibleItems
    are returned by the API
-   `Statement.maxRequestRange` is now set to 31 days and 1 hour instead of 31 days
-   Made `Statement.maxRequestRange` and `Statement.maxPossibleItems`
    modifiable
-   `API.globalTimeout` is not final anymore

## 2.1.0

-   Bump http to 1.1.x

## 2.0.3

-   Added rebuilding card type
-   More careful sendId parsing to avoid exceptions

## 2.0.2

-   Added support for `counterName` field in `StatementItem`
-   Increased upper SDK constraint to declare support for Dart 3
-   Documentation fixes

## 2.0.1

### Mono library

-   Don't throw exception when backend returns `null` as cashback type
    (happens with `fop` account type)

## 2.0.0

### Breaking Changes

-   Minimum Dart version is 2.17.0

#### Money library

-   `CurrencyInfo` now requires a date parameter for both its constructors

#### Mono library

-   `Client.id` and `Account.sendId` changed their types from `String` to `SendId`
-   `Cashback.type` and `Account.cashbackType` changed their types from `String` to `CashbackType`.
    Arbitrary money cashback is not supported anymore.

### What's New

-   Added support for card type `eAid`
-   Added `toString()` implementations for `CardType`, `BankCard`, `Client`, `Account`
-   Fields `Client.id` and `Account.sendId` can now be used to generate `send.monobank.ua` links
    thanks to the new `SendId` type and its `SendId.url` getter
-   Support for getting `webhookUrl` under `Client` and setting one using `Client.setWebhook`
-   Permissions list of the current token with `Client.permissions`
-   Jars list of the current user with `Client.jars`
-   Access FOP invoice ID with `StatementItem.invoiceId`
-   Parse webhook events with `WebhookEvent.fromJson`
-   Added `CurrencyInfo.date` property

## 1.4.5

-   Minor refactoring

## 1.4.4

-   Added support for new API fields

## 1.4.3

-   Dependency update

## 1.4.2

-   Max date range extended to 31 days

## 1.4.1

-   Bugs fixed

## 1.4.0

-   Null safety
-   Bugs fixed

## 1.4.0-nullsafety.1

-   Null safety
-   Bugs fixed

## 1.3.0

-   Breaking change: /mcc/mcc.dart removed
-   Docs fixes

## 1.2.2

-   Fixed CurrencyInfo integer parsing error

## 1.2.0

-   Support for iban
-   Support for fop account type

## 1.1.2

-   isCreditUsed works properly now

## 1.1.1

-   Changed card mask type to String so leading zeros won't ruin the actual value

## 1.1.0

-   Fixed currency getting
-   Getting currency example

## 1.0.7

-   Formatting

## 1.0.6

-   Renamed files

## 1.0.5

-   more dartfmt

## 1.0.4

-   dartfmt fixes

## 1.0.3

-   Combined examples to a single file

## 1.0.2

-   Added examples

## 1.0.1

-   Fix metadata

## 1.0.0

-   Initial version
