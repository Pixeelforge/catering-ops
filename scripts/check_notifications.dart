import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const String appId = "a6be3e2a-c081-4eb2-b797-cb4f13136db4";
  const String restApiKey = "os_v2_app_u27d4kwaqfhlfn4xznhrge3nwtpdrfrkvaterru6pio6x6c6gquxoqdv3saousgmrlnmme6vb3ed5ved2aoxog53h5bdxsxaeqtklwy";

  print('--- OneSignal Configuration Check ---');
  print('App ID: $appId');
  print('API Key: ${restApiKey.substring(0, 10)}...');

  print('\n--- Verifying API Key with OneSignal API ---');
  try {
    final response = await http.get(
      Uri.parse('https://onesignal.com/api/v1/apps/$appId'),
      headers: {
        'Authorization': 'Basic $restApiKey',
      },
    );

    if (response.statusCode == 200) {
      print('✅ OneSignal API Key is VALID.');
      final data = jsonDecode(response.body);
      print('App Name: ${data['name']}');
      print('GCM/FCM Config: ${data['gcm_key'] != null ? 'Present' : 'MISSING'}');
    } else {
      print('❌ OneSignal API Key VALIDATION FAILED.');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error during API Key validation: $e');
  }

  print('\n--- Checking for Recently Created Notifications ---');
  try {
     final response = await http.get(
      Uri.parse('https://onesignal.com/api/v1/notifications?app_id=$appId&limit=5'),
      headers: {
        'Authorization': 'Basic $restApiKey',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List notifications = data['notifications'];
      print('Found ${notifications.length} recent notifications.');
      for (var n in notifications) {
        print('- [${n['send_after'] ?? 'Now'}] "${n['headings']?['en']}" (Status: ${n['successful'] > 0 ? 'SENT' : 'PENDING/FAILED'})');
        if (n['failed'] > 0) {
           print('  ⚠️ FAILED: ${n['failed']} deliveries. Errored: ${n['errored']}');
        }
      }
    } else {
      print('❌ Failed to fetch recent notifications.');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('❌ Error fetching recent notifications: $e');
  }
}
