import 'api.dart';

const String _monoPureDomain = 'https://api.monobank.ua';

class MonoAnonymousAPI extends API {
  MonoAnonymousAPI()
      : super(
          Uri.parse(_monoPureDomain),
          requestTimeouts: {
            'bank/currency': Duration(minutes: 1),
          },
        );
}
