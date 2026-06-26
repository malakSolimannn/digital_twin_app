import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'dashboard_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US', null);

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const DigitalTwinApp());
}

class DigitalTwinApp extends StatelessWidget {
  const DigitalTwinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heart Health',
      theme: AppTheme.light,
      home: const DashboardShell(),
    );
  }
}
