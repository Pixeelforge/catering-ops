import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final envFile = File('apps/mobile_app/assets/.env');
  final envLines = await envFile.readAsLines();

  String? url;
  String? anon;

  for (final line in envLines) {
    if (line.contains('=')) {
      final parts = line.split('=');
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      if (key == 'SUPABASE_URL') url = value;
      if (key == 'SUPABASE_ANON_KEY') anon = value;
    }
  }

  final supabase = SupabaseClient(url!, anon!);

  print('Querying public.profiles...');
  try {
    final profiles = await supabase
        .from('profiles')
        .select('*');
    
    print('Total Profiles found: ${profiles.length}');
    for (var p in profiles) {
      print('Profile: ${p['id']} | Name: ${p['full_name']} | Role: ${p['role']} | Phone: ${p['phone']} | Company ID: ${p['company_id']}');
    }

  } catch (e) {
    print('Error querying profiles: $e');
  }

  print('\nQuerying company_invitations...');
  try {
    final invites = await supabase
        .from('company_invitations')
        .select('*');
    
    print('Total Invitations found: ${invites.length}');
    for (var i in invites) {
      print('Invite: ${i['id']} | Name: ${i['full_name']} | Phone: ${i['phone']}');
    }

  } catch (e) {
    print('Error querying invitations: $e');
  }

  exit(0);
}
