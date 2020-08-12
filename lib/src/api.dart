import 'dart:async';
import 'dart:convert';

import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Possible error types that happen to API
///
/// Is being used in [APIError.type] field to identify different error types so they can be handled programmatically
enum APIErrorType {
  /// Error that is related to an exception that happened locally, like incompatible request flags
  local,

  /// HTTP status code returned by server
  server
}

/// Error that's being thrown by [API] in case of an expected error
///
/// Can be thrown in case of incorrect settings, runtime errors or API response codes which differ from 200
/// Instances of this class contain getters to check for some known error types
class APIError {
  /// Error code
  final int data;

  /// See [APIErrorType]
  final APIErrorType type;

  /// Body of the server response
  final String body;

  /// API Error constructor
  ///
  /// Does not provide side effects;
  /// Type defaults to local
  APIError(this.data, {this.type = APIErrorType.local, this.body = ''});

  /// Checks for flood error thrown by server (429 response code)
  ///
  /// This means requests are being sent too often. Check documentation to set throttling precisely
  bool get isFloodError => type == APIErrorType.server && data == 429;

  /// Checks for access error thrown by server (403 response code)
  ///
  /// This means your credentials are incorrect or you don't have rights to access the resource
  ///
  /// NOTE: Sometimes this error is being generated by the library to point on missing token
  /// for [APIRequest.useAuth] == true requests
  bool get isAccessError => type == APIErrorType.server && data == 403;

  /// Checks for Unknown HTTP Method error thrown by the library
  ///
  /// This means you are trying to use HTTP methods which are not considered as being supported
  /// by this library. Check [APIHttpMethod] for supported methods.
  bool get isUnknownHttpMethodError => type == APIErrorType.local && data == 1;

  /// Checks for Illegal Request error thrown by the library
  ///
  /// This means you are trying to send a request immediatelly when it's impossible, using
  /// mutually-incompatiable flags or passing invalid parameters
  bool get isIllegalRequestError => type == APIErrorType.local && data == 2;

  /// Generates token error
  ///
  /// Specifies behavior of the library when [APIRequest.useAuth] == true is being used on
  /// instances without a token
  factory APIError.tokenError() => APIError(403, type: APIErrorType.server);
}

/// API Requests flags
///
/// These constants are being used to set different properties of request queue processing
/// for independent requests instances. [APIRequest.settings] property is being used for that.
/// The flags are working in bit mask technique. To combine multiple flags use `|` operator
/// ```
/// APIRequest('user-info', settings: APIFlags.skipGlobal | APIFlags.resendOnFlood)
/// ```
class APIFlags {
  /// Allow throttling (enabled by default)
  ///
  /// Allows the request to be delayed if it can't be sent immediatelly. In other case [APIError.isIllegalRequestError] is thrown
  static const waiting = 1;

  /// Ignore by-method throttling
  ///
  /// Lets the request to bypass per-method queue, which is being identified by [APIRequest.methodId] property
  static const skip = 2;

  /// Ignore global throttling
  ///
  /// Lets the request to bypass throttling set by [API.globalTimeout] property
  static const skipGlobal = 4;

  /// Resend on any error
  ///
  /// The request will be kept sending until success on any errors
  ///
  /// WARNING: Be careful to use it with any skip options, it will cause spamming
  static const resend = 8;

  /// Resend on flood error
  ///
  /// The request will be resent if flood error happens
  ///
  /// WARNING: Be careful to use it with any skip options, it will cause spamming
  static const resendOnFlood = 16;
}

/// Available HTTP methods
///
/// Used for [APIRequest.httpMethod]
enum APIHttpMethod {
  /// Send as GET
  ///
  /// NOTICE: It doesn't support body
  GET,

  /// Send as POST
  POST
}

/// Request container
///
/// Contains request metadata and content which's being passed to
/// [API.call] method
class APIRequest {
  /// Creates new request
  ///
  /// - [APIRequest.settings] defaults to [APIFlags.waiting]
  /// - [APIRequest.useAuth] defaults to `false`
  /// - [APIRequest.httpMethod] defaults to [APIHttpMethod.GET]
  APIRequest(
    this.method, {
    this.methodId,
    this.settings = APIFlags.waiting,
    this.useAuth = false,

    /// JSON body to send
    Map<String, String> data,

    /// Headers to send
    ///
    /// ```
    /// Key: Value
    /// ```
    Map<String, String> headers,
    this.httpMethod = APIHttpMethod.GET,
  })  : _completer = Completer(),
        data = data ?? {},
        headers = headers ?? {},
        _originalData = data,
        _originalHeaders = headers;

  /// Request method
  ///
  /// Subpath of API's domain. Leading slash `/` is not needed
  /// ```
  /// String requestUrl = API.domain + APIRequest.method
  /// ```
  ///
  /// *Example: `/bank/currency`*
  final String method;

  /// Method ID, or Request Class
  ///
  /// Can be freely specified to classify the request type so
  /// corresponding throttling rules will be applied. Requests
  /// belong to the same class when:
  /// ```
  /// APIRequestA.methodId == APIRequestB.methodId
  /// ```
  final String methodId;

  /// API Request Flags
  ///
  /// See [APIFlags]
  final int settings;

  /// Attach credentials to the request
  ///
  /// Will throw [APIError.tokenError()] if set to `true` while token is absent
  final bool useAuth;

  /// JSON body to be sent
  final Map<String, String> data, _originalData;

  /// Headers to be sent
  ///
  /// `Content-Type: application/json` and `Accept: application/json`
  /// are being added automatically if not present
  final Map<String, String> headers, _originalHeaders;

  /// HTTP method of the request
  ///
  /// See [APIHttpMethod]
  final APIHttpMethod httpMethod;

  final Completer<APIResponse> _completer;
  bool _isProcessingNeeded = true;

  /// Result of the request
  ///
  /// If request is being throttled or resent, the Future keeps being
  /// uncompleted until final result
  ///
  /// Throws [APIError] if expected error happens
  Future<APIResponse> get result => _completer.future;

  /// Clone specified request
  ///
  /// Each request instance can be resolved only once. If you will
  /// pass it to the same [API] instance more than once it will
  /// redirect your request to the existing result (or existing
  /// pending result).
  ///
  /// If you use the same [APIRequest] instance with different
  /// [API] instances behavior is unspecified
  factory APIRequest.clone(APIRequest request) => APIRequest(request.method,
      methodId: request.methodId,
      data: request._originalData,
      headers: request._originalHeaders,
      httpMethod: request.httpMethod,
      settings: request.settings,
      useAuth: request.useAuth);
}

/// Response given by calling on [APIRequest]
class APIResponse {
  /// Response body
  ///
  /// JSON-demarshalled body of the response.
  ///
  /// Can be `Map<String, dynamic>` if object and `List<dynamic>` if
  /// array.
  final dynamic body;

  /// HTTP Response code
  final int statusCode;

  /// HTTP Response headers
  final Map<String, String> headers;

  APIResponse._(this.body, this.statusCode, this.headers);
}

/// Requests sender and throttling container
///
/// Accepts instances of [APIRequest] on [API.call] method
/// to control their throttling based on settings.
///
/// Is being configured for exact domain and credentials,
/// these fields are final. To change them you need to create
/// a new instance. Also see [APIRequest.clone] documentation that
/// mentions requests instances reuse.
class API {
  /// Build new [API] requests sender
  ///
  /// The instance will be waiting for first [API.call] request
  /// before starting any activity
  API(
    this.domain, {
    this.globalTimeout = Duration.zero,
    this.token,
    Map<String, Duration> requestTimeouts,
    Uri noAuthDomain,
  }) : noAuthDomain = noAuthDomain ?? domain {
    this.requestTimeouts = requestTimeouts ?? {};
  }

  /// Root path
  ///
  /// All the requests are going to be subpaths of this
  final Uri domain;

  /// No authenication Root path
  ///
  /// Is being used instead of [API.domain] when [API.token] is
  /// not present or [APIRequst.useAuth] == `false`.
  ///
  /// Defaults to [API.domain]
  final Uri noAuthDomain;

  /// Request credential
  ///
  /// Is being appended in [API.authAttacher] when
  /// [APIRequst.useAuth] == `true`.
  final String token;

  /// Minimal timeout between all requests
  ///
  /// Every request will be throttled according to this if else
  /// not specified in [APIRequest.settings].
  ///
  /// At least this amount of time should pass before next request
  /// will be sent
  final Duration globalTimeout;

  final Set<APIRequest> _cart = {};
  final Map<String, DateTime> _lastRequests = {};
  final Map<String, bool> _methodBusy = {};

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  bool _cartBusy = false;

  /// Minimal timeout between requests of the same class
  ///
  /// Every request will be throttled according to this if else
  /// not specified in [APIRequest.settings].
  ///
  /// At least this amount of time should pass before next request
  /// of the same class will be sent
  ///
  /// ```
  /// {'class-name': Duration(seconds: 5)}
  /// ```
  Map<String, Duration> requestTimeouts = {};

  /// Returns `true` if there are requests being throttled
  bool get isCartBusy => _cartBusy;

  /// Returns is method \[of class\] is currently in-work
  bool isMethodBusy(String methodId) => _methodBusy[methodId] ?? false;

  /// Returns configured delay between requests of the same class
  ///
  /// Also can be accessed this way:
  /// ```
  /// API.requestTimeouts[methodId]
  /// ```
  ///
  /// Returns `Duration.zero` if not set
  Duration getMethodRequestTimeout(String methodId) =>
      requestTimeouts[methodId] ?? Duration.zero;

  /// Returns last time request was sent
  ///
  /// Returns last time request of class was sent if specified
  ///
  /// Returns `DateTime.fromMillisecondsSinceEpoch(0)` if never was sent
  DateTime lastRequest({String methodId}) => methodId == null
      ? _lastRequest
      : (_lastRequests[methodId] ?? DateTime.fromMillisecondsSinceEpoch(0));

  /// Returns minimum required time until request \[of class\] can be sent
  ///
  /// Returns [Duration.zero] if the request can be sent immediatellly
  ///
  /// Must be checked again before sending the request, because it returns
  /// **minimum** required time, not the actual one
  Duration willFreeIn({String methodId}) {
    // Time since last request
    final timePassed = DateTime.now().difference(_lastRequest);

    // Return delay caused by global timer
    // if not enough time has passed yet
    if (methodId == null) {
      if (timePassed < globalTimeout) {
        return globalTimeout - timePassed;
      }
    }

    // If request class is specified
    if (methodId != null) {
      // Time since last request of time has sent
      final methodTimePassed =
          DateTime.now().difference(lastRequest(methodId: methodId));

      // Minimum delay if the request is being sent right now
      // This works so because the runnig request can finish with
      // an error, so the next request will be able to be sent immediatelly
      if (isMethodBusy(methodId)) {
        return Duration(milliseconds: 1);
      }

      // Get configured timeout
      final requestTimeout = getMethodRequestTimeout(methodId);
      // If not enough time passed for the class - return difference
      if (requestTimeout > methodTimePassed) {
        return requestTimeout - methodTimePassed;
      }
    }

    // Can be sent immediatelly
    return Duration.zero;
  }

  /// Returns `true` if request \[of class\] can be sent immediatelly
  ///
  /// Can be also calculated by comparasion of API.isRequestImmediate
  /// to [Duration.zero]
  bool isRequestImmediate(String methodId) =>
      willFreeIn(methodId: methodId) == Duration.zero;

  /// Evaluate the request
  ///
  /// See [APIRequest] and [APIRequest.result]
  Future<APIResponse> call(APIRequest request) {
    if (!request._isProcessingNeeded) return request.result;

    if (request.useAuth && token == null) {
      throw APIError.tokenError();
    }

    _sendToCart(request);

    return request.result;
  }

  void _sendToCart(APIRequest request) {
    if (((request.settings & APIFlags.skip > 0) ||
            (request.settings & APIFlags.skipGlobal > 0)) &&
        request.settings & APIFlags.waiting == 0) {
      request._completer.completeError(APIError(2));
      return;
    }

    if (request.settings & APIFlags.skipGlobal > 0 &&
        request.settings & APIFlags.skip > 0) {
      if (request.settings & APIFlags.waiting > 0) {
        request._completer.completeError(APIError(2));
        return;
      }
      _sendRequest(request);
      return;
    }

    if (request.settings & APIFlags.waiting > 0) {
      _cart.add(request);
      _cartRunner();
      return;
    }

    if (!isRequestImmediate(request.methodId)) {
      request._completer.completeError(APIError(2));
      return;
    }

    _cart.add(request);
    _cartRunner();
  }

  void _cartRunner({bool recursive = false}) {
    if (isCartBusy && !recursive) return;
    if (_cart.isEmpty) {
      _cartBusy = false;
      return;
    }

    _cartBusy = true;

    Duration globalWait;

    Duration minDelay;

    for (var request in _cart.toList()) {
      try {
        globalWait = willFreeIn();
        if (request.methodId != null) {
          final methodWait = willFreeIn(methodId: request.methodId);
          if (methodWait != Duration.zero &&
              ((request.settings & APIFlags.skip == 0) ||
                  (request.settings & APIFlags.skipGlobal != 0))) {
            minDelay = (minDelay == null
                ? methodWait
                : math.min(minDelay, methodWait));
            continue;
          }
        }

        if (globalWait != Duration.zero &&
            (request.settings & APIFlags.skipGlobal == 0)) continue;

        _sendRequest(request);
        _cart.remove(request);
      } catch (e) {
        if (e is APIError && !e.isIllegalRequestError) {
          _cartBusy = false;
          rethrow;
        }
      }
    }

    if (_cart.isNotEmpty) {
      globalWait = willFreeIn();

      if (globalWait != Duration.zero &&
          (minDelay == null || globalWait < minDelay)) {
        minDelay = globalWait;
      }

      if (minDelay is Duration) {
        Timer(minDelay, () => _cartRunner(recursive: true));
        return;
      }
    }

    _cartBusy = false;
  }

  void _sendRequest(APIRequest request) async {
    final url = request.useAuth ? domain : noAuthDomain;
    final beforeSentMethodTime = lastRequest(methodId: request.methodId);
    final beforeSentTime = lastRequest();
    try {
      request._isProcessingNeeded = false;
      var inLine = (request.settings & APIFlags.skip == 0) &&
          (request.settings & APIFlags.skipGlobal == 0);
      _lastRequest = DateTime.now();
      _lastRequests[request.methodId] = DateTime.now();
      if (inLine) {
        _methodBusy[request.methodId] = true;
      }

      final requestUrl = '$url${request.method}';
      preprocessRequest(request);
      if (request.useAuth) authAttacher(request);

      http.Response response;

      if (request.httpMethod == APIHttpMethod.POST) {
        response = await http.post(requestUrl,
            body: jsonEncode(request.data), headers: request.headers);
      } else if (request.httpMethod == APIHttpMethod.GET) {
        response = await http.get(requestUrl, headers: request.headers);
      } else {
        throw APIError(1);
      }

      if (response.statusCode != 200) {
        throw APIError(response.statusCode,
            type: APIErrorType.server, body: response.body.toString());
      }

      final resolver = APIResponse._(
          json.decode(response.body), response.statusCode, response.headers);

      final stamp = DateTime.now();
      _lastRequest = stamp;
      _lastRequests[request.methodId] = stamp;

      if (inLine) {
        _methodBusy[request.methodId] = false;
      }
      request._completer.complete(resolver);
    } on APIError catch (e) {
      _lastRequest = beforeSentTime;
      _lastRequests[request.methodId] = beforeSentMethodTime;

      if ((e.isFloodError && request.settings & APIFlags.resendOnFlood > 0) ||
          request.settings & APIFlags.resend > 0) {
        _sendToCart(request);
      } else {
        request._completer.completeError(e);
      }
    } catch (e) {
      _lastRequest = beforeSentTime;
      _lastRequests[request.methodId] = beforeSentMethodTime;

      request._completer.completeError(e);
      rethrow;
    }

    _methodBusy[request.methodId] = false;
  }

  /// Attaches credentials to given request
  void authAttacher(APIRequest request) {
    request.headers['X-Token'] = token;
  }

  /// Preprocesses given request
  ///
  /// Adds `Content-Type` and `Accept` headers
  void preprocessRequest(APIRequest request) {
    request.headers.putIfAbsent('Content-Type', () => 'application/json');
    request.headers.putIfAbsent('Accept', () => 'application/json');
  }
}
