import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final envFile = File('assets/.env');
  final envLines = await envFile.readAsLines();

  String? url;
  String? anon;

  for (final line in envLines) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1];
    if (line.startsWith('SUPABASE_ANON_KEY='))
      anon = line.substring('SUPABASE_ANON_KEY='.length);
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
