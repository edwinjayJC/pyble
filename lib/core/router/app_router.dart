import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../constants/route_names.dart';
import '../constants/app_constants.dart';
import '../providers/supabase_provider.dart';
import '../theme/providers/theme_mode_provider.dart';
import '../../features/table/providers/table_provider.dart';
import '../../features/table/models/table_session.dart';
import '../../features/table/models/participant.dart';
import '../../features/auth/providers/user_profile_provider.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/email_verification_pending_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/table/screens/active_tables_screen.dart';
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
import '../../features/history/screens/history_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pyble')),
      drawer: const AppDrawer(),
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
                  onPressed: () => context.push(RoutePaths.activeTables),
                  child: const Text('View My Tables'),
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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: 'Appearance',
            subtitle: 'Tune how Pyble looks and feels.',
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                subtitle: const Text('Reduce glare with a darker palette.'),
                value: themeMode == ThemeMode.dark,
                onChanged: (isDark) => notifier.setThemeMode(
                  isDark ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SettingsSection(
            title: 'Account & Security',
            subtitle: 'Manage your profile and account preferences.',
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(Icons.lock_outline),
                title: Text('Two-factor authentication'),
                subtitle: Text('Coming soon'),
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSection(
            title: 'Danger zone',
            subtitle: 'Delete your account and all associated data.',
            titleColor: colorScheme.error,
            subtitleColor: colorScheme.error.withValues(alpha: 0.8),
            cardColor: colorScheme.error.withValues(alpha: 0.05),
            dividerColor: colorScheme.error.withValues(alpha: 0.15),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text(
                  'Delete account',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    color: colorScheme.error.withValues(alpha: 0.85),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: colorScheme.error.withValues(alpha: 0.8),
                  size: 16,
                ),
                onTap: () => _handleDeleteAccountTap(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccountTap(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProgressDialog(
        title: 'Checking account',
        message:
            'Making sure every table is squared away before closing your account.',
      ),
    );

    try {
      final blockers = await _collectDeletionBlockers(ref);
      rootNavigator.pop();
      if (!context.mounted) return;

      if (blockers.isNotEmpty) {
        await _showBlockersDialog(context, blockers);
        return;
      }

      await _confirmDeleteAccount(context, ref);
    } catch (error) {
      rootNavigator.pop();
      if (!context.mounted) return;

      await _showBlockersDialog(context, [
        _DeletionBlocker(
          icon: Icons.warning_amber_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Couldn’t verify account status',
          message: error is ApiException && error.message.isNotEmpty
              ? error.message
              : 'We ran into an issue checking your tables. Please try again in a moment.',
        ),
      ]);
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'Deleting your account removes all tables, payment information, and history. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    await _deleteAccount(context, ref);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProgressDialog(
        title: 'Deleting account',
        message: 'Hold tight while we securely remove your account.',
      ),
    );

    try {
      await ref.read(userRepositoryProvider).deleteAccount();
      rootNavigator.pop();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );

      await ref.read(supabaseClientProvider).auth.signOut();
      if (!context.mounted) return;
      context.go(RoutePaths.auth);
    } catch (error) {
      rootNavigator.pop();
      if (!context.mounted) return;

      final message = _describeAccountDeletionError(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<List<_DeletionBlocker>> _collectDeletionBlockers(WidgetRef ref) async {
    final blockers = <_DeletionBlocker>[];
    final tableRepository = ref.read(tableRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);

    final activeTable = await tableRepository.getActiveTable();
    if (activeTable == null) return blockers;

    final tableName = _formatTableName(activeTable);
    final isTableOpen =
        activeTable.status != TableStatus.settled &&
        activeTable.status != TableStatus.cancelled;

    if (isTableOpen) {
      blockers.add(
        _DeletionBlocker(
          icon: Icons.table_restaurant,
          title: 'Table still open',
          message:
              '$tableName is still in progress. Finish or cancel it before deleting your account.',
        ),
      );
    }

    final tableData = await tableRepository.getTableData(activeTable.id);
    final unpaidParticipants = tableData.participants
        .where((participant) => participant.paymentStatus != PaymentStatus.paid)
        .toList();

    if (unpaidParticipants.isEmpty) {
      return blockers;
    }

    final currentUserId = currentUser?.id;
    Participant? selfParticipant;
    if (currentUserId != null) {
      for (final participant in unpaidParticipants) {
        if (participant.userId == currentUserId) {
          selfParticipant = participant;
          break;
        }
      }
    }

    if (selfParticipant != null) {
      blockers.add(
        _DeletionBlocker(
          icon: Icons.payments_outlined,
          title: 'You still owe ${_formatCurrency(selfParticipant.totalOwed)}',
          message:
              'Pay your share on $tableName before we can remove your account.',
        ),
      );
    }

    final isHost =
        currentUserId != null && currentUserId == tableData.table.hostUserId;
    final othersStillPaying = unpaidParticipants
        .where((participant) => participant != selfParticipant)
        .toList();

    if (othersStillPaying.isNotEmpty && isHost) {
      final names = _formatNameList(
        othersStillPaying
            .map((participant) => participant.displayName)
            .toList(),
      );
      blockers.add(
        _DeletionBlocker(
          icon: Icons.people_outline,
          title: 'Guests still settling up',
          message:
              '$names still need to settle $tableName. Give them a moment or close the table first.',
        ),
      );
    }

    return blockers;
  }

  Future<void> _showBlockersDialog(
    BuildContext context,
    List<_DeletionBlocker> blockers,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Can’t delete just yet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: blockers
                  .map(
                    (blocker) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            blocker.icon,
                            color: blocker.iconColor ?? colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  blocker.title,
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  blocker.message,
                                  style: Theme.of(
                                    dialogContext,
                                  ).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  String _formatTableName(TableSession table) {
    if (table.title != null && table.title!.trim().isNotEmpty) {
      return table.title!.trim();
    }
    if (table.code.isNotEmpty) {
      return 'Table ${table.code}';
    }
    return 'your table';
  }

  String _formatCurrency(double value) {
    return '${AppConstants.currencySymbol}${value.toStringAsFixed(2)}';
  }

  String _formatNameList(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    if (names.length == 3) {
      return '${names[0]}, ${names[1]} and ${names[2]}';
    }
    final remaining = names.length - 2;
    return '${names[0]}, ${names[1]} and $remaining others';
  }

  String _describeAccountDeletionError(Object error) {
    if (error is ApiException) {
      final status = error.statusCode;
      final serverMessage = _extractServerMessage(error.data);
      final fallbackMessage =
          (error.message.isNotEmpty &&
              error.message.toLowerCase() != 'request failed')
          ? error.message
          : null;
      if (status == 409) {
        return serverMessage ??
            'Looks like you still have an open table or pending payment. Close them out and try again.';
      }
      if (status == 400 || status == 422) {
        return serverMessage ??
            'Your account still has outstanding activity. Please wrap up any open tables before deleting.';
      }
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return serverMessage;
      }
      if (fallbackMessage != null) {
        return fallbackMessage;
      }
      final statusLabel = status != null ? ' (code $status)' : '';
      return 'We couldn’t delete your account$statusLabel. Please try again in a moment.';
    }
    return 'We couldn’t reach the server. Check your connection and try again.';
  }

  String? _extractServerMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      return data;
    }
    if (data is Map) {
      final candidates = [
        'message',
        'detail',
        'error',
        'reason',
        'description',
      ];
      for (final key in candidates) {
        final value = data[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
      final errors = data['errors'];
      if (errors is List) {
        return errors.whereType<String>().join('\n');
      }
    }
    if (data is List) {
      return data.whereType<String>().join('\n');
    }
    return data.toString();
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.cardColor,
    this.dividerColor,
  });

  final String title;
  final List<Widget> children;
  final String? subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? cardColor;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (titleStyle ?? Theme.of(context).textTheme.titleMedium)
              ?.copyWith(color: titleColor),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: (subtitleStyle ?? Theme.of(context).textTheme.bodySmall)
                ?.copyWith(color: subtitleColor),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          color: cardColor,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: dividerColor),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeletionBlocker {
  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;

  const _DeletionBlocker({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
  });
}

class _ProgressDialog extends StatelessWidget {
  final String title;
  final String message;

  const _ProgressDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Flexible(child: Text(message)),
            ],
          ),
        ],
      ),
    );
  }
}

// HistoryScreen is now imported from features/history/screens/history_screen.dart

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isAuthRoute = state.matchedLocation == RoutePaths.auth;
      final isOnboardingRoute = state.matchedLocation == RoutePaths.onboarding;
      final isVerifyRoute = state.matchedLocation == RoutePaths.verifyEmail;
      final isTermsRoute = state.matchedLocation == RoutePaths.terms;

      // Check if tutorial has been seen
      final prefs = await SharedPreferences.getInstance();
      final tutorialSeen = prefs.getBool(AppConstants.tutorialSeenKey) ?? false;

      if (!tutorialSeen && !isOnboardingRoute && !isVerifyRoute) {
        return RoutePaths.onboarding;
      }

      // Not authenticated
      if (!isAuthenticated) {
        if (isAuthRoute || isOnboardingRoute || isVerifyRoute) return null;
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
        path: RoutePaths.activeTables,
        name: RouteNames.activeTables,
        builder: (context, state) => const ActiveTablesScreen(),
      ),
      GoRoute(
        path: RoutePaths.verifyEmail,
        name: RouteNames.verifyEmail,
        builder: (context, state) {
          final email =
              state.uri.queryParameters['email'] ?? 'your email address';
          return EmailVerificationPendingScreen(email: email);
        },
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
