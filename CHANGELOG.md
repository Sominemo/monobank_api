## 2.0.0
### Breaking Changes
- Minimum Dart version is 2.17.0

#### Money library
- `CurrencyInfo` now requires a date parameter for both its constructors

#### Mono library
- `Client.id` and `Account.sendId` changed their types from `String` to `SendId`
- `Cashback.type` and `Account.cashbackType` changed their types from `String` to `CashbackType`. 
  Arbitrary money cashback is not supported anymore.

### What's New
- Added support for card type 'eAid'
- Added `toString()` implementations for `CardType`, `BankCard`, `Client`, `Account`
- Fields `Client.id` and `Account.sendId` can now be used to generate `send.monobank.ua` links
thanks to the new `SendId` type and its `SendId.url` getter
- Support for getting `webhookUrl` under `Client` and setting one using `Client.setWebhook`
- Permissions list of the current token with `Client.permissions`
- Jars list of the current user with `Client.jars`
- Access FOP invoice ID with 'StatementItem.invoiceId`
- Parse webhook events with `WebhookEvent.fromJson`
- Added `CurrencyInfo.date` property

## 1.4.5
- Minor refactoring

## 1.4.4
- Added support for new API fields

## 1.4.3
- Dependency update

## 1.4.2
- Max date range extended to 31 days

## 1.4.1
- Bugs fixed

## 1.4.0
- Null safety
- Bugs fixed

## 1.4.0-nullsafety.1
- Null safety
- Bugs fixed

## 1.3.0
- Breaking change: /mcc/mcc.dart removed
- Docs fixes

## 1.2.2
- Fixed CurrencyInfo integer parsing error

## 1.2.0
- Support for iban
- Support for fop account type

## 1.1.2
- isCreditUsed works properly now

## 1.1.1
- Changed card mask type to String so leading zeros won't ruin the actual value

## 1.1.0
- Fixed currency getting
- Getting currency example

## 1.0.7
- Formatting

## 1.0.6
- Renamed files

## 1.0.5
- more dartfmt

## 1.0.4
- dartfmt fixes

## 1.0.3
- Combined examples to a single file

## 1.0.2
- Added examples

## 1.0.1
- Fix metadata

## 1.0.0
- Initial version