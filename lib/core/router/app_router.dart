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
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/splash_screen.dart';
import '../widgets/app_drawer.dart';

const String _termsContent = '''
TERMS AND CONDITIONS

Last Updated: 11/20/2025


1. DEFINITIONS
In these Terms and Conditions ("Terms"):
- "Pyble", "we", "us", "our" means the owners, operators and licensors of the Pyble mobile application and related services.
- "User", "you", "your" means any person who uses or accesses the Service.
- "Host" means a User who creates a table session, pays the restaurant, and receives reimbursements from other Users (Participants).
- "Participants" means all Users who join a table via QR-code or invite, claim items, and reimburse the Host.
- "Payment Processor" means any third-party payment service provider used by Pyble for handling payments.
- "OCR" means the optical character recognition and AI-powered bill scanning functionality provided by Pyble.
- "Restaurant" means any merchant or venue issuing a bill that is scanned via the Service.


2. DESCRIPTION OF THE SERVICE
Pyble provides a platform that allows Users to:
  • Join a table by scanning a QR code or being invited by a Host;
  • Upload or scan a restaurant bill via OCR/AI;
  • Review itemised bill details and claim or allocate items among Participants;
  • Make payments (via the app or an integrated Payment Processor) to reimburse the Host; and
  • Track the status of reimbursements and bill settlement.


Pyble does not:
  • Pay the restaurant directly;
  • Guarantee that the Host will pay the restaurant or that reimbursements will be made;
  • Act as a bank, escrow agent, fiduciary or guarantor of any payments;
  • Guarantee the accuracy of OCR/AI itemisation;
  • Mediate disputes between Users about payments, claims or reimbursements.


3. ACCEPTANCE OF TERMS
By installing, accessing or using the Service, you agree to be bound by these Terms. If you do not agree, you must immediately cease all use. You represent and warrant that you have the capacity to enter into these Terms and use the Service in compliance with these Terms.


3A. AGE & ELIGIBILITY REQUIREMENTS
(a) You must be at least eighteen (18) years of age to use the payment or reimbursement features of the Service in South Africa, in line with full contractual capacity under the Children's Act 38 of 2005 (age of majority = 18 years).
(b) If you are under eighteen (18) years of age, you may only use the Service with the **express permission** of a parent or legal guardian who has:
  - read and accepted these Terms;
  - agrees to take full responsibility for your actions in using the Service;
  - indemnifies Pyble for any liability arising from your use.
(c) You represent and warrant to us that you satisfy the eligibility and age requirements set out above. You further acknowledge that we do not independently verify your age or capacity, and you accept all liability for any mis-representation of your age or capacity.


4. NO WARRANTY - SERVICE PROVIDED "AS IS" AND "AS AVAILABLE"
You expressly acknowledge and agree that the Service is provided on an "AS IS" and "AS AVAILABLE" basis, without any warranty or representation of any kind, whether express or implied. We disclaim all warranties including, but not limited to, implied warranties of merchantability, fitness for a particular purpose, non-infringement and accuracy. You accept that OCR/AI functionality may produce inaccurate results, that itemisation may be incorrect, and that you must verify all claimed items, totals, taxes, service charges and reimbursements yourself.


5. USER RESPONSIBILITIES
You agree that:
(a) You are solely responsible for verifying the accuracy of the bill, scanned items, claimed items, reimbursements and the Host's payment to the restaurant;
(b) You acknowledge that OCR/AI may mis-read or mis-allocate items and accept the risk of such inaccuracies;
(c) You are responsible for your own payment arrangements, ensuring that you pay your share and reimburse the Host correctly and on time;
(d) You will use the Service in compliance with all applicable laws and not engage in fraudulent, dishonest or abusive conduct (including claiming items you did not consume, sub-allocating incorrectly, avoiding payment, altering bills, or manipulating the itemisation process).


6. HOST RESPONSIBILITIES
If you act as a Host, you acknowledge and agree that:
(a) You are solely responsible for paying the full restaurant bill regardless of whether Participants reimburse you;
(b) You bear the risk that one or more Participants may fail to pay their share, under-pay, or delay payment;
(c) Pyble makes no guarantee that you will be reimbursed by Participants or that the restaurant will accept your settlement;
(d) Pyble accepts no liability if Participants do not pay their share, or if the restaurant disputes the payment or bill amount.


7. USER-TO-USER DISPUTES
All disputes, claims, disagreements or controversies between Users (including Hosts and Participants) relating to claimed items, reimbursements, payments, itemisation, tips, service charges or allocations must be resolved directly between those Users. Pyble is not a party to any such dispute and has no obligation to mediate, adjudicate or become involved. We are not liable for any outcome, loss or damage arising from such disputes.


8. NO FINANCIAL, FIDUCIARY OR ESCROW RELATIONSHIP
You expressly understand and agree that Pyble is not acting as a bank, trustee, escrow agent, financial intermediary or fiduciary with respect to Users. Pyble does not hold or safeguard your funds, does not guarantee any payment settlement, and is not responsible for any Users' financial obligations to each other or to any merchant.


9. PAYMENT PROCESSING DISCLAIMERS
(a) Payments made via the Service are processed by one or more third-party Payment Processors. You agree to the terms, conditions and privacy policies of those providers.
(b) Pyble has no control over, and accepts no liability for: declined transactions, payment processing delays, chargebacks, fraud detection, reversal of payments, cancelled transactions or other payment-related issues.
(c) All financial obligations stemming from a transaction remain between you and the Payment Processor, you and the Host (if you are a Participant), and you and the restaurant (if you are a Host). Pyble is not liable for any failure by any party to meet its obligations.


10. ACCURACY OF INFORMATION
You acknowledge that Pyble does not guarantee the correctness of: OCR/AI-derived itemisations, totals, taxes, service charges, currency conversions, or Participant claims. It is your responsibility to manually verify all bill details, claimed items and reimbursement amounts before proceeding with payment.


11. LIABILITY LIMITATION
To the fullest extent permitted by applicable South African law, Pyble, its affiliates, officers, directors, employees, agents and licensors shall **not be liable** for any direct, indirect, incidental, special, punitive or consequential damages (including lost profits, lost data, lost savings, personal injury or property damage) arising out of or in any way related to your use of or inability to use the Service, including but not limited to:
  • mis-scanned bills, incorrect item allocation or reimbursement failure;
  • inaccuracies or errors in OCR/AI data extraction;
  • any failure by Participants to pay, or delay in payment;
  • payment processing issues;
  • disputes between Users over claims, reimbursements or allocations;
  • any conduct or omissions by Users, restaurants or Payment Processors.


12. LIMITATION OF DAMAGES
Your sole and exclusive remedy for dissatisfaction with the Service is to stop using the Service. To the maximum extent permitted by law, our total liability to you for any claim arising out of or relating to the Service is capped at the greater of (a) R500 or (b) the total amount of fees you have paid to Pyble in the preceding three (3) months (if any). Some jurisdictions may not allow such limitations; if so, the limitation shall apply to the fullest extent permissible.


13. INDEMNIFICATION
You agree to defend, indemnify and hold harmless Pyble, its affiliates, officers, directors, employees and agents from and against all claims, liabilities, damages, losses, costs and expenses (including reasonable attorneys' fees) arising out of or in connection with your use of the Service, your breach of these Terms, or any dispute between you and a restaurant, Host or Participant.


14. DATA & PRIVACY
Your use of the Service is subject to our Privacy Policy, which explains how we collect, use, disclose and safeguard your personal information. You consent to our collection and processing of your data in accordance with the Privacy Policy.


15. MODIFICATIONS TO TERMS OR SERVICE
Pyble reserves the right to modify these Terms or the Service at any time. We will notify you of material changes by updating the "Last Updated" date above or via in-app notification. Your continued use of the Service after any such modification constitutes acceptance of the updated Terms.


16. TERMINATION
We may suspend or terminate your access to the Service at any time, without notice, for any conduct that we determine in our sole discretion violates these Terms, is unlawful, or is otherwise harmful to Pyble, other Users or third parties.


17. CONTACT US
If you have any questions about these Terms or the Service, please contact us at support@pyble.com.
''';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(_termsContent),
                ),
              ),
              const SizedBox(height: 16),
              SafeArea(
                top: false,
                child: SizedBox(
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
              ),
            ],
          ),
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
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isSplashRoute = state.matchedLocation == RoutePaths.splash;
      final isAuthRoute = state.matchedLocation == RoutePaths.auth;
      final isOnboardingRoute = state.matchedLocation == RoutePaths.onboarding;
      final isVerifyRoute = state.matchedLocation == RoutePaths.verifyEmail;
      final isTermsRoute = state.matchedLocation == RoutePaths.terms;

      // Check if tutorial has been seen
      final prefs = await SharedPreferences.getInstance();
      final tutorialSeen = prefs.getBool(AppConstants.tutorialSeenKey) ?? false;

      if (!tutorialSeen && !isOnboardingRoute && !isVerifyRoute && !isSplashRoute) {
        return RoutePaths.onboarding;
      }

      // Not authenticated
      if (!isAuthenticated && !isSplashRoute) {
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
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
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
      // GoRoute(
      //   path: RoutePaths.activeTables,
      //   name: RouteNames.activeTables,
      //   builder: (context, state) => const ActiveTablesScreen(),
      // ),
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

