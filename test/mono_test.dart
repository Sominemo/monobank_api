import 'dart:convert';
import 'dart:io';

import 'package:monobank_api/monobank_api.dart';
import 'package:test/test.dart';

class ResultAnalysis {
  final List<Map<String, dynamic>> missingItems;
  final List<SequenceErrors> sequenceErrors;
  final List<StatementItem> serviceMessages;
  final bool doesDirectionMatch;

  ResultAnalysis({
    required this.missingItems,
    required this.sequenceErrors,
    required this.serviceMessages,
    required this.doesDirectionMatch,
  });
}

class SequenceErrors {
  final int lastId;
  final int currentId;
  final int index;

  SequenceErrors(this.lastId, this.currentId, this.index);
}

void main() {
  group('With Server', () {
    HttpServer? server;
    Uri? url;
    MonoAPI api = MonoAPI('test-token');
    Client? client;
    List<Map<String, dynamic>> items = [];

    setUp(() async {
      final s = await HttpServer.bind('localhost', 0);
      server = s;

      url = Uri.parse('http://${s.address.host}:${s.port}/');

      api = MonoAPI('test-token', domain: url.toString());
      api.requestTimeouts = {};
      api.globalTimeout = Duration(seconds: 0);

      server?.listen((request) async {
        final uri = request.uri;
        final path = uri.path;
        final pathSegments = uri.pathSegments;

        void respond(Object body, {int statusCode = 200}) {
          request.response
            ..statusCode = statusCode
            ..headers.set('Content-Type', 'application/json; charset=utf-8')
            ..write(jsonEncode(body))
            ..close();
        }

        if (path.startsWith('/personal/client-info')) {
          respond({
            'clientId': '3MSaMMtczs',
            'name': 'Мазепа Іван',
            'webHookUrl': 'https://example.com/some_random_data_for_security',
            'permissions': 'psfj',
            'accounts': [
              {
                'id': 'kKGVoZuHWzqVoZuH',
                'sendId': 'uHWzqVoZuH',
                'balance': 10000000,
                'creditLimit': 10000000,
                'type': 'black',
                'currencyCode': 980,
                'cashbackType': 'UAH',
                'maskedPan': ['537541******1234'],
                'iban': 'UA733220010000026201234567890'
              }
            ],
            'jars': [
              {
                'id': 'kKGVoZuHWzqVoZuH',
                'sendId': 'uHWzqVoZuH',
                'title': 'На тепловізор',
                'description': 'На тепловізор',
                'currencyCode': 980,
                'balance': 1000000,
                'goal': 10000000
              }
            ]
          });
        } else if (path.startsWith('/personal/statement')) {
          final startTimestamp = int.parse(pathSegments[3]);
          final endTimestamp = int.parse(pathSegments[4]);

          final start =
              DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000);
          final end = DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000);

          print('Statement Request: $start - $end');

          final timeDifference = end.difference(start);
          if (timeDifference > Statement.maxRequestRange) {
            respond({
              'error': 'Too long period',
              'timeDifference': timeDifference.inMilliseconds ~/ 1000,
              'start': start.toString(),
              'end': end.toString(),
            }, statusCode: 400);
            return;
          }

          final filteredItems = items
              .where((e) {
                final time = DateTime.fromMillisecondsSinceEpoch(
                    (e['time'] as int) * 1000);
                return (time.isAfter(start) && time.isBefore(end) ||
                    time.isAtSameMomentAs(start) ||
                    time.isAtSameMomentAs(end));
              })
              .take(Statement.maxPossibleItems)
              .toList();

          print('Statement Response: ${filteredItems.length}');
          respond(filteredItems);
        } else {
          respond({'error': 'Not Found'}, statusCode: 404);
        }
      });

      client = await api.clientInfo();
    });

    ResultAnalysis validateResult(
        List<StatementItem> result, bool isReverseChronological) {
      final List<Map<String, dynamic>> missingItems = [];
      for (final item in items) {
        if (result.where((e) => e.id == item['id']).isEmpty) {
          missingItems.add(item);
        }
      }

      int? lastId;
      int direction = 0;
      final List<SequenceErrors> sequenceErrors = [];
      final List<StatementItem> serviceMessages = [];

      if (result.length >= 2) {
        final firstId = int.parse(result.first.id);
        final secondId = int.parse(result[1].id);
        direction = secondId - firstId > 0 ? 1 : -1;
      }

      final doesDirectionMatch = direction == (isReverseChronological ? -1 : 1);

      for (int i = 0; i < result.length; i++) {
        final item = result[i];

        if (item.isServiceMessage) {
          serviceMessages.add(item);
          continue;
        }

        if (lastId == null) {
          lastId = int.parse(item.id);
          continue;
        }

        final id = int.parse(item.id);

        if (lastId + direction != id) {
          sequenceErrors.add(SequenceErrors(lastId, id, i));
        }

        lastId = id;
      }

      return ResultAnalysis(
        missingItems: missingItems,
        sequenceErrors: sequenceErrors,
        serviceMessages: serviceMessages,
        doesDirectionMatch: doesDirectionMatch,
      );
    }

    void generateList(List<Map<String, Object>> statementDensity) {
      items.clear();

      int id = 0;
      DateTime time = statementDensity[0]['start'] as DateTime;

      for (int densityDataIndex = 0;
          densityDataIndex < statementDensity.length;
          densityDataIndex++) {
        final densityData = statementDensity[densityDataIndex];
        final start = densityData['start'] as DateTime;
        final end = densityData['end'] as DateTime;
        final density = densityData['density'] as int;
        final interval = end.difference(start).inSeconds / density;
        time = start;

        for (var i = 0; i < density; i++) {
          id++;
          time = time.add(Duration(milliseconds: (interval * 1000).toInt()));
          items.add({
            'id': id.toString(),
            'time': time.millisecondsSinceEpoch ~/ 1000,
            'description': 'Segment $densityDataIndex',
            'mcc': 7997,
            'originalMcc': 7997,
            'hold': false,
            'amount': -95000,
            'operationAmount': -95000,
            'currencyCode': 980,
            'commissionRate': 0,
            'cashbackAmount': 19000,
            'balance': 10050000,
            'comment': 'За каву',
            'receiptId': 'XXXX-XXXX-XXXX-XXXX',
            'invoiceId': '2103.в.27',
            'counterEdrpou': '3096889974',
            'counterIban': 'UA898999980000355639201001404',
            'counterName': 'ТОВАРИСТВО З ОБМЕЖЕНОЮ ВІДПОВІДАЛЬНІСТЮ «ВОРОНА»'
          });
        }
      }

      items = items.reversed.toList();
    }

    tearDown(() async {
      final s = server;
      if (s == null) return;

      await s.close(force: true);
      server = null;
      url = null;
      client = null;
      items.clear();
    });

    test('Get whole range reverse chronological', () async {
      final start = DateTime.utc(2021, 1, 1);
      final end = DateTime.utc(2022, 1, 1);

      final statementDensity = [
        {
          'start': DateTime.utc(2021, 1, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 1, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 2, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 2, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 3, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 3, 31, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 4, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 4, 30, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 5, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 5, 31, 23, 59, 59),
          'density': 200,
        },
        {
          'start': DateTime.utc(2021, 6, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 6, 30, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 7, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 7, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 2),
          'density': 500,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 3),
          'end': DateTime.utc(2021, 8, 31, 23, 59, 59),
          'density': 1000,
        },
        {
          'start': DateTime.utc(2021, 9, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 9, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 10, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 10, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 11, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 11, 30, 23, 59, 59),
          'density': 20,
        },
        {
          'start': DateTime.utc(2021, 12, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 12, 31, 23, 59, 59),
          'density': 5,
        },
      ];

      generateList(statementDensity);

      final fetchedItems = await client!.accounts[0]
          .statement(start, end)
          .list(includeServiceMessages: true, isReverseChronological: true)
          .toList();

      final analysis = validateResult(fetchedItems, true);

      expect(analysis.missingItems, isEmpty, reason: 'Missing items');
      expect(analysis.sequenceErrors, isEmpty, reason: 'Sequence errors');
      expect(analysis.serviceMessages, isEmpty,
          reason: 'Should not have errors');
      expect(analysis.doesDirectionMatch, isTrue, reason: 'Direction mismatch');
      expect(fetchedItems, hasLength(items.length), reason: 'Length mismatch');
    });

    test('Get whole range chronological', () async {
      final start = DateTime.utc(2021, 1, 1);
      final end = DateTime.utc(2022, 1, 1);

      final statementDensity = [
        {
          'start': DateTime.utc(2021, 1, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 1, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 2, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 2, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 3, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 3, 31, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 4, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 4, 30, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 5, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 5, 31, 23, 59, 59),
          'density': 200,
        },
        {
          'start': DateTime.utc(2021, 6, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 6, 30, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 7, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 7, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 2),
          'density': 500,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 3),
          'end': DateTime.utc(2021, 8, 31, 23, 59, 59),
          'density': 1000,
        },
        {
          'start': DateTime.utc(2021, 9, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 9, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 10, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 10, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 11, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 11, 30, 23, 59, 59),
          'density': 20,
        },
        {
          'start': DateTime.utc(2021, 12, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 12, 31, 23, 59, 59),
          'density': 5,
        },
      ];

      generateList(statementDensity);

      final fetchedItems = await client!.accounts[0]
          .statement(start, end)
          .list(includeServiceMessages: true, isReverseChronological: false)
          .toList();

      final analysis = validateResult(fetchedItems, false);

      expect(analysis.missingItems, isEmpty, reason: 'Missing items');
      expect(analysis.sequenceErrors, isEmpty, reason: 'Sequence errors');
      expect(analysis.serviceMessages, isEmpty,
          reason: 'Should not have errors');
      expect(analysis.doesDirectionMatch, isTrue, reason: 'Direction mismatch');
      expect(fetchedItems, hasLength(items.length), reason: 'Length mismatch');
    });

    test('Get whole range reverse chronological w/ one error', () async {
      final start = DateTime.utc(2021, 1, 1);
      final end = DateTime.utc(2022, 1, 1);

      final statementDensity = [
        {
          'start': DateTime.utc(2021, 1, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 1, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 2, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 2, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 3, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 3, 31, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 4, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 4, 30, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 5, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 5, 31, 23, 59, 59),
          'density': 200,
        },
        {
          'start': DateTime.utc(2021, 6, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 6, 30, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 7, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 7, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 2),
          'density': 501,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 3),
          'end': DateTime.utc(2021, 8, 31, 23, 59, 59),
          'density': 1000,
        },
        {
          'start': DateTime.utc(2021, 9, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 9, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 10, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 10, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 11, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 11, 30, 23, 59, 59),
          'density': 20,
        },
        {
          'start': DateTime.utc(2021, 12, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 12, 31, 23, 59, 59),
          'density': 5,
        },
      ];

      generateList(statementDensity);

      final fetchedItems = await client!.accounts[0]
          .statement(start, end)
          .list(includeServiceMessages: true, isReverseChronological: true)
          .toList();

      final analysis = validateResult(fetchedItems, true);

      expect(analysis.missingItems, hasLength(1),
          reason: 'Should have missing items reported');
      expect(analysis.sequenceErrors, hasLength(1),
          reason: 'Sequence errors should be reported');
      expect(analysis.serviceMessages, hasLength(1),
          reason: 'Should have one service message');
      expect(analysis.doesDirectionMatch, isTrue, reason: 'Direction mismatch');
      expect(fetchedItems, hasLength(items.length),
          reason:
              'Should have same length, missing item compensated by service message');
    });

    test('Get whole range chronological w/ one error', () async {
      final start = DateTime.utc(2021, 1, 1);
      final end = DateTime.utc(2022, 1, 1);

      final statementDensity = [
        {
          'start': DateTime.utc(2021, 1, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 1, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 2, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 2, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 3, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 3, 31, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 4, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 4, 30, 23, 59, 59),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 5, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 5, 31, 23, 59, 59),
          'density': 200,
        },
        {
          'start': DateTime.utc(2021, 6, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 6, 30, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 7, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 7, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'density': 400,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 1),
          'end': DateTime.utc(2021, 8, 1, 0, 0, 2),
          'density': 501,
        },
        {
          'start': DateTime.utc(2021, 8, 1, 0, 0, 3),
          'end': DateTime.utc(2021, 8, 31, 23, 59, 59),
          'density': 1000,
        },
        {
          'start': DateTime.utc(2021, 9, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 9, 30, 23, 59, 59),
          'density': 100,
        },
        {
          'start': DateTime.utc(2021, 10, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 10, 31, 23, 59, 59),
          'density': 0,
        },
        {
          'start': DateTime.utc(2021, 11, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 11, 30, 23, 59, 59),
          'density': 20,
        },
        {
          'start': DateTime.utc(2021, 12, 1, 0, 0, 0),
          'end': DateTime.utc(2021, 12, 31, 23, 59, 59),
          'density': 5,
        },
      ];

      generateList(statementDensity);

      final fetchedItems = await client!.accounts[0]
          .statement(start, end)
          .list(includeServiceMessages: true, isReverseChronological: false)
          .toList();

      final analysis = validateResult(fetchedItems, false);

      expect(analysis.missingItems, hasLength(1),
          reason: 'Should have missing items reported');
      expect(analysis.sequenceErrors, hasLength(1),
          reason: 'Sequence errors should be reported');
      expect(analysis.serviceMessages, hasLength(1),
          reason: 'Should have one service message');
      expect(analysis.doesDirectionMatch, isTrue, reason: 'Direction mismatch');
      expect(fetchedItems, hasLength(items.length),
          reason:
              'Should have same length, missing item compensated by service message');
    });
  }, timeout: Timeout(Duration(seconds: 10)));
}
