import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run scripts/check_onesignal.dart <User_ID>');
    print('Example: dart run scripts/check_onesignal.dart 550e8400-e29b-41d4-a716-446655440000');
    return;
  }

  final externalId = args[0];

  final envFile = File('apps/mobile_app/assets/.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found at apps/mobile_app/assets/.env');
    return;
  }

  final envContent = envFile.readAsLinesSync();
  String? appId;
  String? restKey;

  for (var line in envContent) {
    if (line.startsWith('ONESIGNAL_APP_ID=')) {
      appId = line.split('=')[1].trim().replaceAll('"', '').replaceAll("'", "");
    }
    if (line.startsWith('ONESIGNAL_REST_API_KEY=')) {
      restKey = line.split('=')[1].trim().replaceAll('"', '').replaceAll("'", "");
    }
  }

  if (appId == null || restKey == null) {
    print('Error: ONESIGNAL_APP_ID or ONESIGNAL_REST_API_KEY not found in .env');
    return;
  }

  print('🔍 Checking OneSignal status for External ID: $externalId...');
  
  final url = Uri.parse('https://onesignal.com/api/v1/players?app_id=$appId');
  
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Basic $restKey',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final players = data['players'] as List;
      
      final player = players.firstWhere(
        (p) => p['external_user_id'] == externalId,
        orElse: () => null,
      );

      if (player != null) {
        print('✅ User Found!');
        print('OneSignal ID: ${player['id']}');
        print('Status: ${player['invalid_identifier'] == true ? '❌ INVALID' : '✅ ACTIVE'}');
        print('Tags: ${player['tags']}');
        print('Last Active: ${player['last_active']}');
        print('Device Type: ${player['device_type']} (1=iOS, 2=Android)');
      } else {
        print('❌ User not found in OneSignal for this App ID.');
        print('Make sure NotificationService.login("$externalId") was called in the app.');
      }
    } else {
      print('Error from OneSignal: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Fatal Error: $e');
  }
}
