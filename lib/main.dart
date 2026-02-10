import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth_wrapper.dart';

/// ApexRun - Performance Running Platform
///
/// Main application entry point with Supabase and Riverpod initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } else {
    // Show configuration error but allow app to start
    debugPrint('WARNING: ${Env.configurationErrorMessage}');
  }

  runApp(
    const ProviderScope(
      child: ApexRunApp(),
    ),
  );
}

class ApexRunApp extends StatelessWidget {
  const ApexRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if app is configured
    if (!Env.isConfigured) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Configuration Error',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Env.configurationErrorMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'ApexRun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}
