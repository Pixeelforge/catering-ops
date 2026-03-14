import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  static const String appId = "e03d985c-4050-41d6-88fd-092232fa325b";
  static const String restApiKey = "os_v2_app_4a6zqxcakba5nch5berdf6rsln7csm6bakjuxanhzhiglq4s2dd6hjwsevcyhurozruzg4gxmudcomcnswrixp4a4hp7kkwhj2jrzwq";

  /// Initialize OneSignal globally (called in main.dart)
  static Future<void> setupOneSignal() async {
    try {
      debugPrint('🔔 OneSignal: Initializing with App ID: $appId');
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
      
      // Opt-in for notifications
      OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 OneSignal: Setup complete');
    } catch (e) {
      debugPrint('🔔 OneSignal Error: Setup failed: $e');
    }
  }

  /// Login user to OneSignal once Supabase auth is resolved
  static void login(String userId) {
    try {
      debugPrint('🔔 OneSignal: Logging in user: $userId');
      OneSignal.login(userId);
    } catch (e) {
      debugPrint('🔔 OneSignal Error: Login failed: $e');
    }
  }

  static Future<void> sendNotification({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_external_user_ids': playerIds,
          'headings': {'en': title},
          'contents': {'en': message},
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Notification sent successfully: ${response.body}');
      } else {
        debugPrint('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  static Future<void> sendToCompany({
    required String companyId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'filters': [
            {'field': 'tag', 'key': 'company_id', 'relation': '=', 'value': companyId},
            {'field': 'tag', 'key': 'role', 'relation': '=', 'value': 'staff'},
          ],
          'headings': {'en': title},
          'contents': {'en': message},
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Company notification sent: ${response.body}');
      } else {
        debugPrint('Failed to send company notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending company notification: $e');
    }
  }
}
