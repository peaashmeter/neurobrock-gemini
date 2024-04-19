import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:neurobrock/auth.dart';
import 'package:neurobrock/constants.dart';

Future<String> generatePhrase(String input) async {
  final accessToken = (await obtainCredentials()).accessToken.data;

  final body = {
    "contents": [
      {
        "parts": [
          {"text": input}
        ],
      },
    ],
    "safetySettings": [
      {
        "category": 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
        "threshold": "BLOCK_NONE"
      },
      {"category": 'HARM_CATEGORY_HATE_SPEECH', "threshold": "BLOCK_NONE"},
      {"category": 'HARM_CATEGORY_HARASSMENT', "threshold": "BLOCK_NONE"},
      {
        "category": 'HARM_CATEGORY_DANGEROUS_CONTENT',
        "threshold": "BLOCK_NONE"
      },
    ]
  };

  final response =
      await http.post(Uri.parse('$baseUrl/v1/$modelName:generateContent'),
          headers: {
            HttpHeaders.contentTypeHeader: "application/json",
            HttpHeaders.authorizationHeader: "Bearer $accessToken",
            "x-goog-user-project": projectId
          },
          body: jsonEncode(body));

  try {
    final output = jsonDecode(response.body);
    return _handleResponse(output);
  } catch (e) {
    return e.toString();
  }
}

String _handleResponse(dynamic data) {
  try {
    if (data["candidates"].first['finishReason'] == 'SAFETY') {
      return '[ДАННЫЕ УДАЛЕНЫ]';
    }

    return (data["candidates"].first['content']['parts'].first as Map)
        .values
        .reduce((value, element) => value + element);
  } catch (e) {
    return e.toString();
  }
}
