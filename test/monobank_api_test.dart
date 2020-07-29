import 'package:monobank_api/main.dart';
import 'package:test/test.dart';

void main() {
  group('Test API constructor', () {
    API api;

    setUp(() {
      api = API(Uri.parse('https://api.monobank.ua'));
    });

    test('Initial wait value is correct', () {
      expect(api.willFreeIn(), equals(Duration.zero));
    });
  });
}
