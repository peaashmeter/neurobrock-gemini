import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:neurobrock/secret/credentials.dart';

Future<AccessCredentials> obtainCredentials() async {
  final scopes = [
    'https://www.googleapis.com/auth/generative-language.tuning',
    'https://www.googleapis.com/auth/cloud-platform'
  ];

  final client = http.Client();
  AccessCredentials credentials =
      await obtainAccessCredentialsViaServiceAccount(
          ServiceAccountCredentials.fromJson(json), scopes, client);

  client.close();
  return credentials;
}
