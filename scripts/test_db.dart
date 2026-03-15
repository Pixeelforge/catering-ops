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

  print('Authenticating as a random staff...');
  try {
    // Generate a random email to register as a new staff
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final staffEmail = 'staff_$timestamp@test.com';

    final AuthResponse res = await supabase.auth.signUp(
      email: staffEmail,
      password: 'password123',
      data: {'full_name': 'Test Staff', 'phone': '1234567890', 'role': 'staff'},
    );

    final user = res.user;
    if (user == null) {
      print('Failed to create user.');
      exit(1);
    }

    print('Staff created with ID: ${user.id}');

    // Wait for the trigger to insert into profiles
    await Future.delayed(Duration(seconds: 2));

    // Fetch profile
    final profile = await supabase
        .from('profiles')
        .select('full_name, company_id')
        .eq('id', user.id)
        .maybeSingle();

    print('Fetched profile: ${profile ?? 'NULL'}');

    // Try to view any company
    try {
      final companies = await supabase.from('companies').select().limit(1);
      print('First company: $companies');
      if (companies.isNotEmpty) {
        final code = companies[0]['id'];
        print('Attempting to join company: $code');

        final companyRes = await supabase
            .from('companies')
            .select('id')
            .eq('id', code)
            .maybeSingle();
        print('Verified company: $companyRes');

        print('Updating profile...');
        await supabase
            .from('profiles')
            .update({'company_id': code})
            .eq('id', user.id);

        print('Updated successfully!');
      } else {
        print('No companies found.');
      }
    } catch (e) {
      print('Error accessing companies or updating profile: $e');
    }
  } catch (e) {
    print('General Error: $e');
  }

  exit(0);
}
