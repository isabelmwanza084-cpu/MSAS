import 'dart:convert';
import 'package:http/http.dart' as http;

class ZamboxService {
  static const String _baseUrl = 'https://zambox.zambrite.com/api/messaging/v1/sms/send';
  
  // Active Zambox API key
 static const String _apiKey = 'omk_25c0be94.7c4b8d247f7eb09048500e7e91c31c05a61f5e615a653087';
  static Future<bool> sendSms({
    required String recipientPhone, 
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "to": recipientPhone,
          "body": message,
          "senderId": "Natosnako", // Update if Zambox provides a verified/default Sender ID
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Zambox SMS sent successfully!');
        return true;
      } else {
        print('Zambox Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception while sending Zambox SMS: $e');
      return false;
    }
  }
}