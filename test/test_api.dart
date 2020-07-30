import 'dart:io';

import 'package:monobank_api/main.dart';
import 'package:test/test.dart';

void main() {
  API api;

  setUp(() {
    api = API(Uri.parse('http://example.com/'),
        globalTimeout: Duration(seconds: 3),
        requestTimeouts: {
          'test-class1': Duration(seconds: 5),
          'test-class2': Duration(seconds: 2),
          'test-class3': Duration(seconds: 0),
        });
  });

  group('[API Static]', () {
    test('Initial wait value is correct', () {
      expect(api.willFreeIn(), equals(Duration.zero));
    });

    test('Initial wait value for method with Duration > 0 is 0', () {
      expect(api.willFreeIn(methodId: 'test-class1'), equals(Duration.zero));
    });

    test('Initial wait value for method with Duration == 0 is 0', () {
      expect(api.willFreeIn(methodId: 'test-class3'), equals(Duration.zero));
    });

    test('Initial cart status is not busy', () {
      expect(api.isCartBusy, equals(false));
    });

    test('APIError generates correct token error', () {
      expect(APIError.tokenError().isAccessError, equals(true));
    });

    test('APIRequest is composable with minimum set of arguments', () {
      expect(() => APIRequest('test'), returnsNormally);
    });

    test('APIRequest is composable with maximum set of arguments', () {
      expect(
          () => APIRequest('test',
              methodId: 'test-class1',
              settings: APIFlags.skip,
              useAuth: true,
              data: {'key': 'value'},
              headers: {'Header': 'Value'},
              httpMethod: APIHttpMethod.POST),
          returnsNormally);
    });

    test('useAuth requests without token throw APIError', () async {
      try {
        await api.call(APIRequest('test', useAuth: true));
        fail('Invalid call didn\'t throw anything');
      } catch (e) {
        expect(e.isAccessError, equals(true));
      }
    });

    test('APIRequest.clone basic test', () {
      var request = APIRequest('test',
          methodId: 'test-class1',
          settings: APIFlags.skip,
          useAuth: true,
          data: {'key': 'value'},
          headers: {'Header': 'Value'},
          httpMethod: APIHttpMethod.POST);

      var clone = APIRequest.clone(request);
      expect(clone.httpMethod, equals(request.httpMethod));
    });
  });

  group('[API]', () {
    HttpServer server;
    Uri url;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      url = Uri.parse('http://${server.address.host}:${server.port}/');
    });

    tearDown(() async {
      await server.close(force: true);
      server = null;
      url = null;
    });

    test('Initial wait value is correct', () {
      expect(api.willFreeIn(), equals(Duration.zero));
    });
  }, skip: 'Under construction');
}
