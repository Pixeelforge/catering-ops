import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get oneSignalAppId => dotenv.env['ONESIGNAL_APP_ID']!;
  static String get oneSignalRestKey => dotenv.env['ONESIGNAL_REST_API_KEY']!;
}