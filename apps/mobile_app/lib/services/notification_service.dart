import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import '../main.dart';

class NotificationService {
  static String get appId => Env.oneSignalAppId;
  // REST API Key removed for security, now handled by Supabase Edge Functions
  static bool _isInitialized = false;

  /// Initialize OneSignal globally (called in main.dart)
  static Future<void> setupOneSignal() async {
    try {
      debugPrint('🔔 OneSignal: Initializing with App ID: $appId');
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
      
      // Opt-in for notifications
      OneSignal.Notifications.requestPermission(true);

      // 🔹 FORWARD DISPLAY (Ensure it pops up when app is open)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('🔔 OneSignal: Foreground Notification: ${event.notification.title}');
        event.notification.display(); // Force display even in foreground
      });

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
          } else if (['direct_assignment', 'bidding', 'fastest_claim', 'order_delivered', 'order_reminder', 'auction_won', 'request_accepted', 'request_rejected', 'order_bid'].contains(type)) {
            // Orders Page (Index 1 for Owner) or main StaffView
            NotificationService.targetTab = 1;
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/dashboard', (route) => false);
          } else {
            // Default Dashboard (Index 0)
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
  static Future<void> login(String userId) async {
    try {
      await OneSignal.login(userId);
      debugPrint("OneSignal: Logged in user $userId");
    } catch (e) {
      debugPrint("OneSignal: Error logging in (already handled?): $e");
    }
  }

  static Future<void> refreshTags({
    required String companyId,
    required String role,
  }) async {
    try {
      await OneSignal.User.addTags({
        'company_id': companyId,
        'role': role,
      });
      debugPrint("OneSignal: Tags refreshed ($role, $companyId)");
    } catch (e) {
      debugPrint("OneSignal: Error refreshing tags: $e");
    }
  }

  static Future<void> logout() async {
    try {
      await OneSignal.logout();
      await OneSignal.User.removeTag('company_id');
      await OneSignal.User.removeTag('role');
    } catch (e) {
      debugPrint("OneSignal: Error logging out: $e");
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

  /// Centralized logic to send notifications via Supabase Edge Function
  static Future<String?> _invokeNotifyFunction(Map<String, dynamic> payload) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: payload,
      );

      if (response.status == 200) {
        debugPrint('🔔 Edge Function: Success: ${response.data}');
        return null;
      } else {
        return 'Edge Function Error: ${response.status}: ${response.data}';
      }
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> sendNotification({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String color = 'FFD4A237',
    DateTime? sendAfter,
    bool saveToDb = true,
    String? companyId,
  }) async {
    debugPrint('🔔 OneSignal: Requesting notification trigger for $playerIds');
    
    final payload = {
      'playerIds': playerIds,
      'title': title,
      'message': message,
      'data': data,
      'color': color,
      if (sendAfter != null) 'sendAfter': sendAfter.toUtc().toIso8601String(),
    };

    final err = await _invokeNotifyFunction(payload);
    
    if (err == null) {
      _showTriggerToast(title);
      
      // 🔹 Persistent History: Save to Notifications table (only for immediate notifications)
      if (saveToDb && sendAfter == null) {
        try {
          final client = Supabase.instance.client;
          final List<Map<String, dynamic>> inserts = playerIds.map((id) => {
            'owner_id': id,
            'title': title,
            'message': message,
            'company_id': companyId,
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }).toList();
          
          if (inserts.isNotEmpty) {
            await client.from('notifications').insert(inserts);
          }
        } catch (e) {
          debugPrint('🔔 Notification History Error: $e');
        }
      }
    }
    return err;
  }

  /// Private helper to show a confirmation toast globally
  static void _showTriggerToast(String title) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orangeAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Sent',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF161626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.orangeAccent, width: 0.5),
          ),
        ),
      );
    }
  }

  static Future<String?> sendToCompany({
    required String companyId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String color = 'FFD4A237',
    DateTime? sendAfter,
    bool saveToDb = true,
  }) async {
    debugPrint('🔔 OneSignal: Requesting company notification ($companyId)');
    
    final payload = {
      'companyId': companyId,
      'title': title,
      'message': message,
      'data': data,
      'color': color,
      if (sendAfter != null) 'sendAfter': sendAfter.toUtc().toIso8601String(),
    };

    final err = await _invokeNotifyFunction(payload);
    
    if (err == null) {
      _showTriggerToast(title);
      
      // 🔹 Persistent History: Save for all staff members in the company
      if (saveToDb) {
        try {
          final client = Supabase.instance.client;
          // 1. Find all staff members in this company
          final List<dynamic> staff = await client
              .from('profiles')
              .select('id')
              .eq('company_id', companyId)
              .eq('role', 'staff');
          
          if (staff.isNotEmpty) {
            final List<Map<String, dynamic>> inserts = staff.map((s) => {
              'owner_id': s['id'],
              'title': title,
              'message': message,
              'company_id': companyId,
              'is_read': false,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }).toList();
            
            await client.from('notifications').insert(inserts);
          }
        } catch (e) {
          debugPrint('🔔 Notification History Error (Company): $e');
        }
      }
    }
    return err;
  }
}
