import 'dart:convert';
import 'package:http/http.dart' as http;

class ZamboxService {
  static const String _baseUrl = 'https://zambox.zambrite.com/backend/api/messaging/v1/sms';
  
  // Your Zambox API key
  static const String _apiKey = 'omk_aab89f3c.e7a7f2b47f096ed37814d5db0fa7da9fea313b9b32229315';

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
          "recipient": recipientPhone,
          "message": message,
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