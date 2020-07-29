import 'package:monobank_api/main.dart';
void main() {
  var client = API(Uri.parse('https://api.monobank.ua/'),
      token: 'urRZXWbbxW35gJkMmQ0Nn05poKwaMDB2osbDaooeGgPc',
      globalTimeout: Duration(seconds: 8),
      requestTimeouts: {'personal/client-info': Duration(seconds: 5), 'bank/currency': Duration(minutes: 1)});

  var request1 = APIRequest('personal/client-info',
      methodId: 'personal/client-info',
      useAuth: true,
      httpMethod: APIHttpMethod.GET);

  var request2 = APIRequest('bank/currency',
      methodId: 'bank/currency', useAuth: true, httpMethod: APIHttpMethod.GET);

  var clientInfo = client.call(request1);
  var currency = client.call(request2);
      
  clientInfo.then((value) => print('Your ID is: '+ value.body['clientId']));
  currency.then((value) => print('Monobank-supported currencies amount is: '+ value.body.length.toString()));
}
