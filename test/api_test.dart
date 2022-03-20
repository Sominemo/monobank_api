import 'dart:convert';
import 'dart:io';

import 'package:monobank_api/monobank_api.dart';
import 'package:test/test.dart';

class EmptyApiResponse implements APIResponse {
  EmptyApiResponse()
      : body = <String, dynamic>{},
        statusCode = 0,
        headers = {};

  @override
  final dynamic body;
  @override
  final int statusCode;
  @override
  final Map<String, String> headers;
}

void main() {
  var api = API(Uri.parse('http://example.com/'));
  const threshold = 100;
  const timeouts = {
    'test-class1': Duration(seconds: 1),
  };

  setUp(() {
    api = API(Uri.parse('http://example.com/'),
        globalTimeout: Duration(seconds: 2), requestTimeouts: timeouts);
  });

  group('Static', () {
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
      } on APIError catch (e) {
        expect(e.isAccessError, equals(true));
      }
    });

    test('APIRequest.clone basic test', () {
      final request = APIRequest('test',
          methodId: 'test-class1',
          settings: APIFlags.skip,
          useAuth: true,
          data: {'key': 'value'},
          headers: {'Header': 'Value'},
          httpMethod: APIHttpMethod.POST);

      final clone = APIRequest.clone(request);
      expect(clone.httpMethod, equals(request.httpMethod));
    });
  });

  group('With Server', () {
    HttpServer? server;
    Uri? url;
    var api = API(Uri.parse('https://example.com'));
    DateTime? time;

    setUp(() async {
      final s = await HttpServer.bind('localhost', 0);
      server = s;

      final u = Uri.parse('http://${s.address.host}:${s.port}/');
      url = u;

      api = API(u, globalTimeout: Duration(seconds: 3), requestTimeouts: {
        'test-class1': Duration(seconds: 5),
        'test-class2': Duration(seconds: 2),
        'test-class3': Duration(seconds: 0),
      });
      time = DateTime.now();
    });

    tearDown(() async {
      final s = server;
      if (s == null) return;

      await s.close(force: true);
      server = null;
      url = null;
      time = null;
    });

    test('Method is being passed correctly', () {
      api.call(APIRequest('test-method'));
      server?.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(request.uri.path, '/test-method');
      }));
    });

    test('Initial request is being sent immediately', () {
      api.call(APIRequest('test-method'));
      server?.listen(expectAsync1((request) async {
        final received = DateTime.now();

        request.response.write('{}');
        await request.response.close();

        expect(received.difference(time ?? DateTime(0)),
            lessThan(Duration(milliseconds: threshold)));
      }));
    });

    test('Methods can be busy', () {
      api.call(APIRequest('test-method', methodId: 'test-class1'));
      server?.listen(expectAsync1((request) async {
        final business = api.isMethodBusy('test-class1');

        request.response.write('{}');
        await request.response.close();

        expect(business, equals(true));
      }));
    });

    test('Request time is being recorded', () {
      final originalTime = api.lastRequest();
      api.call(APIRequest('test-method'));

      server?.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(originalTime, isNot(equals(api.lastRequest())));
      }));
    });

    test('Request time is being recorded correctly', () {
      api.call(APIRequest('test-method'));

      server?.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(DateTime.now().millisecondsSinceEpoch,
            closeTo(api.lastRequest().millisecondsSinceEpoch, threshold));
      }));
    });

    test('Request time for methodId is being recorded', () {
      final originalTime = api.lastRequest(methodId: 'test-class1');
      api.call(APIRequest('test-method', methodId: 'test-class1'));

      server?.listen(expectAsync1((request) async {
        request.response.write('{}');
        await request.response.close();

        expect(originalTime,
            isNot(equals(api.lastRequest(methodId: 'test-class1'))));
      }));
    });

    group('Cloning and Delivery', () {
      var api = API(Uri());
      APIRequest originalAPIRequest, cloneAPIRequest;
      HttpRequest? originalRequest, cloneRequest;
      late Map<String, dynamic> oDec, cDec;

      setUp(() async {
        api = API(url ?? Uri(), token: 'my-test-token');

        originalAPIRequest = APIRequest('test-method',
            data: {'test-field': 'test-value'},
            headers: {'X-Test-Header': 'test-value'},
            httpMethod: APIHttpMethod.POST,
            settings: APIFlags.skipGlobal | APIFlags.waiting,
            useAuth: true);

        cloneAPIRequest = APIRequest.clone(originalAPIRequest);

        server?.listen((request) async {
          if (originalRequest == null) {
            originalRequest = request;
            oDec = jsonDecode(await utf8.decodeStream(originalRequest!))
                as Map<String, dynamic>;
          } else {
            cloneRequest = request;
            cDec = jsonDecode(await utf8.decodeStream(cloneRequest!))
                as Map<String, dynamic>;
          }

          request.response.write('{}');
          await request.response.close();
        });

        await api.call(originalAPIRequest);
        await api.call(cloneAPIRequest);
      });

      test('Method', () {
        expect(originalRequest?.uri, equals(cloneRequest?.uri));
      });

      test('HTTP Method', () {
        expect(originalRequest?.method, equals(cloneRequest?.method));
      });

      test('Header', () {
        expect(originalRequest?.headers.value('X-Test-Header'),
            equals(cloneRequest?.headers.value('X-Test-Header')));
      });

      test('Token', () {
        expect(originalRequest?.headers.value('X-Token'),
            equals(cloneRequest?.headers.value('X-Token')));
      });

      test('Body value', () {
        expect(oDec['test-field'], cDec['test-field']);
      });
    });

    group('Cart', () {
      group('Flags', () {
        const timeouts = {
          'test-class1': Duration(seconds: 3),
          'test-class2': Duration(seconds: 1),
          'test-class3': Duration(seconds: 0),
        };
        var api = API(Uri());

        setUp(() {
          api = API(url ?? Uri(),
              globalTimeout: Duration(seconds: 2), requestTimeouts: timeouts);
        });

        test('waiting', () {
          final wait =
              api.getMethodRequestTimeout('test-class1').inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.waiting, methodId: 'test-class1');

          DateTime? lastTime;

          server?.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime?.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 5)));

        test('waiting: method timeout is less than global', () {
          final request = APIRequest('test-method',
              settings: APIFlags.waiting, methodId: 'test-class2');

          DateTime? lastTime;

          server?.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime?.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(
                  DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(api.globalTimeout.inMilliseconds,
                      api.globalTimeout.inMilliseconds + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 5)));

        test('skip: Throws without agreeing for waiting', () {
          final request = APIRequest('test-method', settings: APIFlags.skip);

          server?.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();
            // Request must not be delivered
          }, count: 0));

          final cb = expectAsync1((error) {
            if (error is APIError) {
              expect(error.isIllegalRequestError, equals(true));
            }

            return error;
          });

          api.call(request).catchError((Object o) {
            cb(o);
            return EmptyApiResponse();
          });
        });

        test('skip | waiting: Works on no-throttling', () {
          api = API(url!);
          final wait = Duration.zero.inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.waiting,
              methodId: 'test-class1');

          DateTime? lastTime;

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime!.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 1)));

        test('skipGlobal | waiting: Works on no-throttling', () {
          api = API(url!);
          final wait = Duration.zero.inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.skipGlobal | APIFlags.waiting,
              methodId: 'test-class2');

          DateTime? lastTime;

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime!.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        });

        test('skipGlobal: Throws without agreeing for waiting', () {
          final request =
              APIRequest('test-method', settings: APIFlags.skipGlobal);

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();
            fail('Request must not be delivered');
          }, count: 0));

          final cb = expectAsync1((error) {
            if (error is APIError) {
              expect(error.isIllegalRequestError, equals(true));
            }

            return error;
          });

          api.call(request).catchError((Object o) {
            cb(o);
            return EmptyApiResponse();
          });
        });

        test('resend', () {
          var count = 0;
          final request = APIRequest('test-method', settings: APIFlags.resend);

          server!.listen(expectAsync1((request) async {
            if (count == 0) {
              request.response.statusCode = HttpStatus.forbidden;
              count++;
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 2));

          api.call(request);
        });

        test('resendOnFlood | waiting', () async {
          var count = 0;
          final request1 = APIRequest('test-method',
              settings: APIFlags.resendOnFlood | APIFlags.waiting);
          final request2 = APIRequest('test-method2');

          server!.listen(expectAsync1((request) async {
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
          final wait = api.globalTimeout.inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.waiting,
              methodId: 'test-class1');

          DateTime? lastTime;

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime!.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 4)));

        test('skip | waiting: method delay is less than global timeout', () {
          final wait = api.globalTimeout.inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.waiting,
              methodId: 'test-class2');

          DateTime? lastTime;

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime!.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 3)));

        test('skipGlobal | waiting', () {
          final wait =
              api.getMethodRequestTimeout('test-class1').inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.skipGlobal | APIFlags.waiting,
              methodId: 'test-class1');

          DateTime? lastTime;

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime!.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 4)));

        test('skipGlobal | waiting: method delay is less than global timeout',
            () {
          final wait =
              api.getMethodRequestTimeout('test-class2').inMilliseconds;
          final request = APIRequest('test-method',
              settings: APIFlags.skipGlobal | APIFlags.waiting,
              methodId: 'test-class2');

          DateTime? lastTime;

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();

            if (lastTime == null) {
              lastTime = DateTime.now();

              expect(lastTime!.difference(time!),
                  lessThan(Duration(milliseconds: threshold)));
            } else {
              expect(DateTime.now().difference(lastTime!).inMilliseconds,
                  inClosedOpenRange(wait, wait + threshold));
            }
          }, count: 2));

          api.call(request);
          api.call(APIRequest.clone(request));
        }, timeout: Timeout(Duration(seconds: 3)));

        test('skip | skipGlobal | waiting: Throws illegal request error', () {
          final request = APIRequest('test-method',
              settings: APIFlags.skip | APIFlags.skipGlobal | APIFlags.waiting);

          server!.listen(expectAsync1((request) async {
            request.response.write('{}');
            await request.response.close();
            fail('Request must not be delivered');
          }, count: 0));

          final cb = expectAsync1((error) {
            if (error is APIError) {
              expect(error.isIllegalRequestError, equals(true));
            }

            return error;
          });

          api.call(request).catchError((Object o) {
            cb(o);
            return EmptyApiResponse();
          });
        });

        test('resendOnFlood | waiting: Correct wait times for global',
            () async {
          DateTime? last;
          final request1 = APIRequest('test-method',
              settings: APIFlags.resendOnFlood | APIFlags.waiting);

          server!.listen(expectAsync1((request) async {
            if (last == null) {
              last = DateTime.now();
              request.response.statusCode = HttpStatus.tooManyRequests;
            } else {
              expect(DateTime.now().difference(last!).inMilliseconds,
                  closeTo(0, threshold));
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 2));

          await api.call(request1);
        });

        test('resendOnFlood | waiting: Correct wait times for method',
            () async {
          DateTime? last;
          final request1 = APIRequest('test-method',
              settings: APIFlags.resendOnFlood | APIFlags.waiting,
              methodId: 'test-class1');

          server!.listen(expectAsync1((request) async {
            if (last == null) {
              last = DateTime.now();
              request.response.statusCode = HttpStatus.tooManyRequests;
            } else {
              expect(DateTime.now().difference(last!).inMilliseconds,
                  closeTo(0, threshold));
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 2));

          await api.call(request1);
        });

        test('resend | waiting: Correct wait times for global', () async {
          DateTime? last;
          final request1 = APIRequest('test-method',
              settings: APIFlags.resend | APIFlags.waiting);

          server!.listen(expectAsync1((request) async {
            if (last == null) {
              last = DateTime.now();
              request.response.statusCode = HttpStatus.notFound;
            } else {
              expect(DateTime.now().difference(last!).inMilliseconds,
                  closeTo(0, threshold));
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 2));

          await api.call(request1);
        });

        test('resend | waiting: Correct wait times for method', () async {
          DateTime? last;
          final request1 = APIRequest('test-method',
              settings: APIFlags.resend | APIFlags.waiting,
              methodId: 'test-class1');

          server!.listen(expectAsync1((request) async {
            if (last == null) {
              last = DateTime.now();
              request.response.statusCode = HttpStatus.tooManyRequests;
            } else {
              expect(DateTime.now().difference(last!).inMilliseconds,
                  closeTo(0, threshold));
            }
            request.response.write('{}');
            await request.response.close();
          }, count: 2));

          await api.call(request1);
        });
      });
    });
  }, timeout: Timeout(Duration(seconds: 1)));
}
