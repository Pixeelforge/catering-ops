import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../main.dart';

class NotificationService {
  static const String appId = "a6be3e2a-c081-4eb2-b797-cb4f13136db4";
  static const String restApiKey = "os_v2_app_u27d4kwaqfhlfn4xznhrge3nwtpdrfrkvaterru6pio6x6c6gquxoqdv3saousgmrlnmme6vb3ed5ved2aoxog53h5bdxsxaeqtklwy";
  static bool _isInitialized = false;

  /// Initialize OneSignal globally (called in main.dart)
  static Future<void> setupOneSignal() async {
    try {
      debugPrint('🔔 OneSignal: Initializing with App ID: $appId');
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
      
      // Opt-in for notifications
      OneSignal.Notifications.requestPermission(true);

      // 🔹 Notification Click Handling (Deep Linking)
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        debugPrint('🔔 OneSignal: Notification Clicked. Data: $data');
        
        if (data != null && data['type'] != null) {
          final String type = data['type'].toString();
          
          if (type == 'staff_request') {
            // Join Requests (Index 2 for Owner)
            NotificationService.targetTab = 2;
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/dashboard', (route) => false);
          } else if (['direct_assignment', 'bidding', 'fastest_claim', 'order_delivered', 'order_reminder'].contains(type)) {
            // Orders Page (Index 1 for Owner)
            NotificationService.targetTab = 1;
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/dashboard', (route) => false);
          } else {
            // Default Dashbord (Index 0)
            NotificationService.targetTab = 0;
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/dashboard', (route) => false);
          }
        }
      });

      _isInitialized = true;
      debugPrint('🔔 OneSignal: Setup complete');
    } catch (e) {
      debugPrint('🔔 OneSignal Error: Setup failed: $e');
    }
  }

  static int targetTab = 0; // Helper for Deep Linking

  /// Login user to OneSignal once Supabase auth is resolved
  static void login(String userId) {
    if (!_isInitialized) {
      debugPrint('🔔 OneSignal Warning: login() called before setupOneSignal()');
    }
    try {
      debugPrint('🔔 OneSignal: Logging in user: $userId');
      OneSignal.login(userId);
    } catch (e) {
      debugPrint('🔔 OneSignal Error: Login failed: $e');
    }
  }

  /// Helper to send a test notification to the current user
  static Future<String?> sendToSelf(String userId) async {
    debugPrint('🔔 OneSignal: Sending test notification to $userId');
    return await sendNotification(
      playerIds: [userId],
      title: 'Test Notification',
      message: 'If you see this, push notifications are working! 🎉',
      data: {'type': 'test'},
    );
  }

  static Future<String?> sendNotification({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String color = 'FFD4A237',
    DateTime? sendAfter,
  }) async {
    try {
      debugPrint('🔔 OneSignal: Sending notification to $playerIds: "$title"${sendAfter != null ? " (Scheduled for $sendAfter)" : ""}');
      
      final Map<String, dynamic> body = {
        'app_id': appId,
        'include_external_user_ids': playerIds,
        'headings': {'en': title},
        'contents': {'en': message},
        'data': data,
        'android_accent_color': color,
      };

      if (sendAfter != null) {
        // OneSignal expects "YYYY-MM-DD HH:MM:SS OFFSET" or ISO-8601
        // Using UTC to avoid timezone issues
        body['send_after'] = sendAfter.toUtc().toIso8601String().replaceFirst('Z', ' GMT+0000');
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $restApiKey',
         },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('🔔 OneSignal: Success: ${response.body}');
        return null;
      } else {
        final err = 'Build: 23:00 - Status ${response.statusCode}: ${response.body}';
        debugPrint('🔔 OneSignal Error: $err');
        return err;
      }
    } catch (e) {
      final err = e.toString();
      debugPrint('🔔 OneSignal Error: $err');
      return err;
    }
  }

  static Future<String?> sendToCompany({
    required String companyId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String color = 'FFD4A237',
    DateTime? sendAfter,
  }) async {
    try {
      debugPrint('🔔 OneSignal: Sending company notification ($companyId): "$title"');
      
      final Map<String, dynamic> body = {
        'app_id': appId,
        'filters': [
          {'field': 'tag', 'key': 'company_id', 'relation': '=', 'value': companyId},
          {'field': 'tag', 'key': 'role', 'relation': '=', 'value': 'staff'},
        ],
        'headings': {'en': title},
        'contents': {'en': message},
        'data': data,
        'android_accent_color': color,
      };

      if (sendAfter != null) {
        body['send_after'] = sendAfter.toUtc().toIso8601String().replaceFirst('Z', ' GMT+0000');
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $restApiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('🔔 OneSignal: Success: ${response.body}');
        return null;
      } else {
        final err =
            'Build: 23:00 - Status ${response.statusCode}: ${response.body}';
        debugPrint('🔔 OneSignal Error: $err');
        return err;
      }
    } catch (e) {
      final err = e.toString();
      debugPrint('🔔 OneSignal Error: $err');
      return err;
    }
  }
}
