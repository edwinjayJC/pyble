import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/route_names.dart';
import '../constants/app_constants.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/terms_screen.dart';
import '../../features/table/screens/home_screen.dart';
import '../../features/table/screens/create_table_screen.dart';
import '../../features/table/screens/scan_bill_screen.dart';
import '../../features/table/screens/add_items_screen.dart';
import '../../features/table/screens/host_invite_screen.dart';
import '../../features/table/screens/join_table_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/table/providers/profile_provider.dart';
import '../providers/supabase_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);

  return GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: routerNotifier,
    redirect: routerNotifier.redirect,
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
        path: RoutePaths.terms,
        name: RouteNames.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
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
        path: RoutePaths.addItems,
        name: RouteNames.addItems,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return AddItemsScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.hostInvite,
        name: RouteNames.hostInvite,
        builder: (context, state) {
          final tableId = state.pathParameters['tableId']!;
          return HostInviteScreen(tableId: tableId);
        },
      ),
      GoRoute(
        path: RoutePaths.joinTable,
        name: RouteNames.joinTable,
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return JoinTableScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: RoutePaths.history,
        name: RouteNames.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    initialLocation: RoutePaths.onboarding,
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isAuth = false;
  bool _hasAcceptedTerms = false;

  RouterNotifier(this._ref) {
    _ref.listen(currentUserProvider, (_, __) => notifyListeners());
    _ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }

  Future<String?> redirect(BuildContext context, GoRouterState state) async {
    final user = _ref.read(currentUserProvider);
    final profileState = _ref.read(userProfileProvider);
    final isLoggingIn = state.matchedLocation == RoutePaths.auth;
    final isOnboarding = state.matchedLocation == RoutePaths.onboarding;
    final isTerms = state.matchedLocation == RoutePaths.terms;

    // Check if tutorial has been seen
    final prefs = await SharedPreferences.getInstance();
    final tutorialSeen = prefs.getBool(AppConstants.tutorialSeenKey) ?? false;

    // If tutorial not seen, go to onboarding
    if (!tutorialSeen && !isOnboarding) {
      return RoutePaths.onboarding;
    }

    // If not logged in
    if (user == null) {
      _isAuth = false;
      _hasAcceptedTerms = false;
      // Allow onboarding and auth screens
      if (isOnboarding || isLoggingIn) {
        return null;
      }
      return RoutePaths.auth;
    }

    // User is logged in
    _isAuth = true;

    // Check profile state
    if (profileState.isLoading) {
      // Still loading profile, don't redirect yet
      return null;
    }

    final profile = profileState.value;

    // If profile doesn't exist or terms not accepted
    if (profile == null || !profile.hasAcceptedTerms) {
      _hasAcceptedTerms = false;
      if (isTerms) {
        return null;
      }
      return RoutePaths.terms;
    }

    // User is fully authenticated and has accepted terms
    _hasAcceptedTerms = true;

    // Redirect away from auth/onboarding/terms if already logged in
    if (isLoggingIn || isOnboarding || isTerms) {
      return RoutePaths.home;
    }

    return null;
  }
}
