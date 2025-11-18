import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/providers/theme_mode_provider.dart';

Future<void> main() async {
  // Catch all unhandled async errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Supabase with deep link configuration
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('Database error saving new user')) {
        debugPrint('Supabase trigger error (user may still be authenticated): ${details.exception}');
        return;
      }
      FlutterError.presentError(details);
    };

    runApp(
      const ProviderScope(
        child: PybleApp(),
      ),
    );
  }, (error, stackTrace) {
    // Handle unhandled async exceptions
    if (error.toString().contains('Database error saving new user')) {
      debugPrint('Supabase trigger error caught (user may still be authenticated): $error');
      // Don't rethrow - user is likely authenticated despite the error
    } else {
      debugPrint('Unhandled error: $error\n$stackTrace');
    }
  });
}

class PybleApp extends ConsumerWidget {
  const PybleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
