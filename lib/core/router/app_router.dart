import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/route_names.dart';
import '../constants/app_constants.dart';
import '../providers/supabase_provider.dart';
import '../../features/auth/providers/user_profile_provider.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/table/screens/create_table_screen.dart';
import '../../features/table/screens/host_invite_screen.dart';
import '../../features/table/screens/join_table_screen.dart';
import '../../features/table/screens/claim_screen.dart';
import '../../features/ocr/screens/scan_bill_screen.dart';
import '../../features/payments/screens/host_dashboard_screen.dart';
import '../../features/payments/screens/participant_payment_screen.dart';
import '../../features/payments/screens/payment_webview_screen.dart';
import '../../features/payments/screens/payment_processing_screen.dart';
import '../../features/payments/models/payment_record.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pyble'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFB70043),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userProfile.valueOrNull?.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    userProfile.valueOrNull?.email ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(context);
                context.push(RoutePaths.history);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push(RoutePaths.settings);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFD95300)),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFD95300)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(supabaseClientProvider).auth.signOut();
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Color(0xFFB70043),
              ),
              const SizedBox(height: 24),
              Text(
                'Split bills easily',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a table to start splitting a bill with friends',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push(RoutePaths.createTable),
                  child: const Text('Create Table'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push(RoutePaths.joinTable),
                  child: const Text('Join Table'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'Terms and Conditions\n\n'
                  '1. By using Pyble, you agree to these terms.\n\n'
                  '2. The app is provided as-is without warranty.\n\n'
                  '3. You are responsible for your own payment arrangements.\n\n'
                  '4. We do not store sensitive payment information.\n\n'
                  '5. All disputes should be resolved between users.\n\n'
                  '... (More terms would go here)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref.read(userProfileProvider.notifier).acceptTerms();
                  if (context.mounted) {
                    context.go(RoutePaths.home);
                  }
                },
                child: const Text('Accept & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Screen - Coming Soon')),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(child: Text('History Screen - Coming Soon')),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isAuthRoute = state.matchedLocation == RoutePaths.auth;
      final isOnboardingRoute = state.matchedLocation == RoutePaths.onboarding;
      final isTermsRoute = state.matchedLocation == RoutePaths.terms;

      // Check if tutorial has been seen
      final prefs = await SharedPreferences.getInstance();
      final tutorialSeen = prefs.getBool(AppConstants.tutorialSeenKey) ?? false;

      if (!tutorialSeen && !isOnboardingRoute) {
        return RoutePaths.onboarding;
      }

      // Not authenticated
      if (!isAuthenticated) {
        if (isAuthRoute || isOnboardingRoute) return null;
        return RoutePaths.auth;
      }

      // Authenticated but on auth route
      if (isAuthenticated && isAuthRoute) {
        return RoutePaths.home;
      }

      // Check terms acceptance
      final profile = userProfile.valueOrNull;
      if (profile != null && !profile.hasAcceptedTerms && !isTermsRoute) {
        return RoutePaths.terms;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.terms,
        name: RouteNames.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.history,
        name: RouteNames.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.createTable,
        name: RouteNames.createTable,
        builder: (context, state) => const CreateTableScreen(),
      ),
      GoRoute(
        path: RoutePaths.scanBill,
        name: RouteNames.scanBill,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return ScanBillScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.inviteParticipants,
        name: RouteNames.inviteParticipants,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return HostInviteScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.joinTable,
        name: RouteNames.joinTable,
        builder: (context, state) {
          // Handle deep link: pyble://join?code=ABC123
          final code = state.uri.queryParameters['code'];
          if (code != null && code.isNotEmpty) {
            return JoinTableScreen(initialCode: code);
          }
          return const JoinTableScreen();
        },
      ),
      GoRoute(
        path: RoutePaths.claimTable,
        name: RouteNames.claimTable,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return ClaimScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.hostDashboard,
        name: RouteNames.hostDashboard,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return HostDashboardScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.participantPayment,
        name: RouteNames.participantPayment,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return ParticipantPaymentScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.paymentWebview,
        name: RouteNames.paymentWebview,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          final paymentResponse = state.extra as InitiatePaymentResponse;
          return PaymentWebviewScreen(
            tableId: tableId,
            paymentResponse: paymentResponse,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.paymentProcessing,
        name: RouteNames.paymentProcessing,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          final extra = state.extra as Map<String, dynamic>?;
          final paymentId = extra?['paymentId'] as String? ?? '';
          return PaymentProcessingScreen(
            tableId: tableId,
            paymentId: paymentId,
          );
        },
      ),
    ],
  );
});
