import 'dart:convert';
import 'dart:io';

import 'package:monobank_api/main.dart';
import 'package:test/test.dart';

void main() {
  API api;
  const threshold = 100;
  const timeouts = {
    'test-class1': Duration(seconds: 1),
  };

  setUp(() {
    api = API(Uri.parse('http://example.com/'),
        globalTimeout: Duration(seconds: 2), requestTimeouts: timeouts);
  });

  group('[API Static]', () {
    test('Initial wait value is correct', () {
      expect(api.willFreeIn(), equals(Duration.zero));
    });

    test('Method request timeout is given correctly', () {
      expect(api.getMethodRequestTimeout('test-class1'),
          equals(timeouts['test-class1']));
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
    API api;
    DateTime time;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      url = Uri.parse('http://${server.address.host}:${server.port}/');
      api = API(url, globalTimeout: Duration(seconds: 3), requestTimeouts: {
        'test-class1': Duration(seconds: 5),
        'test-class2': Duration(seconds: 2),
        'test-class3': Duration(seconds: 0),
      });
      time = DateTime.now();
    });

    tearDown(() async {
      await server.close(force: true);
      server = null;
      url = null;
      api = null;
      time = null;
    });

    test('Method is being passed correctly', () {
      api.call(APIRequest('test-method'));
      server.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(request.uri.path, '/test-method');
      }));
    });

    test('Initial request is being sent immediatelly', () {
      api.call(APIRequest('test-method'));
      server.listen(expectAsync1((request) async {
        var received = DateTime.now();

        request.response.write('{}');
        await request.response.close();

        expect(received.difference(time),
            lessThan(Duration(milliseconds: threshold)));
      }));
    });

    test('Methods can be busy', () {
      api.call(APIRequest('test-method', methodId: 'test-class1'));
      server.listen(expectAsync1((request) async {
        var business = api.isMethodBusy('test-class1');

        request.response.write('{}');
        await request.response.close();

        expect(business, equals(true));
      }));
    });

    test('Request time is being recorded', () {
      var originalTime = api.lastRequest();
      api.call(APIRequest('test-method'));

      server.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(originalTime, isNot(equals(api.lastRequest())));
      }));
    });

    test('Request time is being recorded correctly', () {
      api.call(APIRequest('test-method'));

      server.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(DateTime.now().millisecondsSinceEpoch,
            closeTo(api.lastRequest().millisecondsSinceEpoch, threshold));
      }));
    });

    test('Request time for methodId is being recorded', () {
      var originalTime = api.lastRequest(methodId: 'test-class1');
      api.call(APIRequest('test-method', methodId: 'test-class1'));

      server.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(originalTime,
            isNot(equals(api.lastRequest(methodId: 'test-class1'))));
      }));
    });

    group('[Clonnig]', () {
      API api;
      APIRequest originalAPIRequest, cloneAPIRequest;
      HttpRequest originalRequest, cloneRequest;
      var oDec, cDec;

      setUp(() async {
        api = API(url, token: 'my-test-token');

        originalAPIRequest = APIRequest('test-method',
            data: {'test-field': 'test-value'},
            headers: {'X-Test-Header': 'test-value'},
            httpMethod: APIHttpMethod.POST,
            settings: APIFlags.skipGlobal,
            useAuth: true);

        cloneAPIRequest = APIRequest.clone(originalAPIRequest);

        server.listen((request) async {
          if (originalRequest == null) {
            originalRequest = request;
            oDec = jsonDecode(await utf8.decodeStream(originalRequest));
          } else {
            cloneRequest = request;
            cDec = jsonDecode(await utf8.decodeStream(cloneRequest));
          }

          request.response.write('{}');
          await request.response.close();
        });

        await api.call(originalAPIRequest);
        await api.call(cloneAPIRequest);
      });

      test('Method', () {
        expect(originalRequest.uri, equals(cloneRequest.uri));
      });

      test('HTTP Method', () {
        expect(originalRequest.method, equals(cloneRequest.method));
      });

      test('Header', () {
        expect(originalRequest.headers.value('X-Test-Header'),
            equals(cloneRequest.headers.value('X-Test-Header')));
      });

      test('Token', () {
        expect(originalRequest.headers.value('X-Token'),
            equals(cloneRequest.headers.value('X-Token')));
      });

      test('Body value', () {
        expect(oDec['test-field'], cDec['test-field']);
      });
    });

    group('[Cart]', () {
      group('[Flags]', () {
        const timeouts = {
          'test-class1': Duration(seconds: 3),
          'test-class2': Duration(seconds: 1),
          'test-class3': Duration(seconds: 0),
        };
        API api;

        setUp(() {
          api = API(url,
              globalTimeout: Duration(seconds: 2), requestTimeouts: timeouts);
        });

        test('waiting', () {
          var wait = api.getMethodRequestTimeout('test-class1').inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.waiting, methodId: 'test-class1');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 5)));

        test('waiting: method timeout is less than global', () {
          var request = APIRequest('test-method',
              settings: APIFlags.waiting, methodId: 'test-class2');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(
                  DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(api.globalTimeout.inMilliseconds,
                      api.globalTimeout.inMilliseconds + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 5)));

        test('skip: Throws without agreeing for waiting', () {
          var request = APIRequest('test-method', settings: APIFlags.skip);

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();
          }, count: 1));
          api.call(request);
          api.call(APIRequest.clone(request)).catchError(expectAsync1((error) {
            expect(error.isIllegalRequestError, equals(true));
          }));
        });

        test('skip: Works on no-throttling', () {
          api = API(url);
          var wait = Duration.zero.inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.skip, methodId: 'test-class1');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 1)));

        test('skipGlobal: Works on no-throttling', () {
          api = API(url);
          var wait = Duration.zero.inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.skipGlobal, methodId: 'test-class2');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        });

        test('skipGlobal: Throws without agreeing for waiting', () {
          var request =
              APIRequest('test-method', settings: APIFlags.skipGlobal);

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();
            fail('Request must not be delivered');
          }));

          api.call(request).catchError(expectAsync1((error) {
            expect(error.isIllegalRequestError, equals(true));
          }));
        });

        test('resend', () {
          var count = 0;
          var request = APIRequest('test-method', settings: APIFlags.resend);

          server.listen(expectAsync1((request) async {
            if (count == 0) {
              request.response.statusCode = HttpStatus.forbidden;
              count++;
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 2));

          api.call(request);
        });

        test('resendOnFlood', () async {
          var count = 0;
          var request1 =
              APIRequest('test-method', settings: APIFlags.resendOnFlood);
          var request2 = APIRequest('test-method2');

          server.listen(expectAsync1((request) async {
            count++;
            if (count == 1) {
              request.response.statusCode = HttpStatus.tooManyRequests;
            }
            if (count == 2) {
              expect(request.uri.path, equals('/test-method'));
              request.response.statusCode = HttpStatus.notFound;
            }
            if (count == 3) {
              expect(request.uri.path, equals('/test-method2'));
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 3));

          try {
            await api.call(request1);
          } catch (e) {
            // Should throw
          }

          await api.call(request2);
        });

        test('skip | waiting', () {
          var wait = api.globalTimeout.inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.waiting,
              methodId: 'test-class1');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 4)));

        test('skip | waiting: method delay is less than global timeout', () {
          var wait = api.globalTimeout.inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.waiting,
              methodId: 'test-class2');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 3)));

        test('skipGlobal | waiting', () {
          var wait = api.getMethodRequestTimeout('test-class1').inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.skipGlobal | APIFlags.waiting,
              methodId: 'test-class1');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 4)));

        test('skipGlobal | waiting: method delay is less than global timeout',
            () {
          var wait = api.getMethodRequestTimeout('test-class2').inMilliseconds;
          var request = APIRequest('test-method',
              settings: APIFlags.skipGlobal | APIFlags.waiting,
              methodId: 'test-class2');

          DateTime lastTime;

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime.difference(time),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 3)));

        test('skip | skipGlobal | waiting: Throws illegal request error', () {
          var request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.skipGlobal | APIFlags.waiting);

          server.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();
            fail('Request must not be delivered');
          }));

          api.call(request).catchError(expectAsync1((error) {
            expect(error.isIllegalRequestError, equals(true));
          }));
        });
      });
    });
  }, timeout: Timeout(Duration(seconds: 1)));
}
