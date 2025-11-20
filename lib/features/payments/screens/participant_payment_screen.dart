import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pyble/features/payments/providers/payment_provider.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_provider.dart';

// Feature Imports
import '../../table/providers/table_provider.dart';
import '../../table/models/participant.dart';
import '../../table/models/table_session.dart'; // For PaymentStatus
import '../repository/payment_repository.dart';

class ParticipantPaymentScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ParticipantPaymentScreen({super.key, required this.tableId});

  @override
  ConsumerState<ParticipantPaymentScreen> createState() =>
      _ParticipantPaymentScreenState();
}

class _ParticipantPaymentScreenState
    extends ConsumerState<ParticipantPaymentScreen> {
  bool _isProcessing = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Hard refresh to ensure status is accurate
    ref.invalidate(currentTableProvider);
    await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
  }

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(currentTableProvider);
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settle Up', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/table/${widget.tableId}/claim');
            }
          },
        ),
      ),
      body: SafeArea(
        child: tableAsync.when(
          data: (tableData) {
            if (tableData == null || currentUser == null) {
              return const Center(child: Text('No data available'));
            }

            final me = tableData.participants.firstWhere(
                  (p) => p.userId == currentUser.id,
              orElse: () => Participant(
                id: 'unknown',
                tableId: '',
                userId: 'unknown',
                displayName: '?',
                paymentStatus: PaymentStatus.owing,
              ),
            );

            final host = tableData.participants.firstWhere(
                  (p) => p.userId == tableData.table.hostUserId,
              orElse: () => me,
            );

            return _buildScreenContent(context, me, host);
          },
          loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text('Error: $error'),
                TextButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenContent(
      BuildContext context,
      Participant me,
      Participant host,
      ) {
    // 1. SETTLED
    if (me.paymentStatus == PaymentStatus.paid) {
      return _buildSettledView(context, me);
    }

    // 2. PENDING (Paid Outside App)
    if (me.paymentStatus == PaymentStatus.pendingConfirmation) {
      return _buildPendingView(context, me, host);
    }

    // 3. PENDING DIRECT (Paid Restaurant Directly)
    if (me.paymentStatus == PaymentStatus.pendingDirectConfirmation) {
      return _buildPendingDirectView(context, me, host);
    }

    // 4. OWING
    return _buildOwingView(context, me, host);
  }

  // === VIEW 1: SETTLED ===
  Widget _buildSettledView(BuildContext context, Participant me) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 64, color: AppColors.lushGreen),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              "You're All Set!",
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.lushGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Payment of ${AppConstants.currencySymbol}${me.totalOwed.toStringAsFixed(2)} confirmed',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  // === VIEW 2: PENDING ===
  Widget _buildPendingView(BuildContext context, Participant me, Participant host) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.lightWarmSpice,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top, size: 48, color: AppColors.warmSpice),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Waiting for Host',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.warmSpice,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You marked this as paid manually.\nWaiting for ${host.displayName} to confirm.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.warmSpice),
          ],
        ),
      ),
    );
  }

  // === VIEW 2B: PENDING DIRECT (Paid Restaurant Directly) ===
  Widget _buildPendingDirectView(BuildContext context, Participant me, Participant host) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.lightWarmSpice,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, size: 48, color: AppColors.warmSpice),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Waiting for Host',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.warmSpice,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You marked this as paid directly to the restaurant.\nWaiting for ${host.displayName} to confirm.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.warmSpice),
          ],
        ),
      ),
    );
  }

  // === VIEW 3: OWING (THE SELECTION SCREEN) ===
  Widget _buildOwingView(
      BuildContext context,
      Participant me,
      Participant host,
      ) {
    final theme = Theme.of(context);
    final amount = me.totalOwed;
    // UPDATE: Fee dropped to 2%
    final fee = amount * 0.02;
    final totalWithFee = amount + fee;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // 1. Bill Summary Receipt
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.allLg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'YOU OWE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      letterSpacing: 1.5
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("To: ", style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(host.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            'Select Payment Method',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 2. OPTION A: PAY IN APP (The "Happy Path")
          // We visually prioritize this to encourage adoption despite the (small) fee.
          _buildInAppPaymentOption(
              context,
              amount: amount,
              fee: fee,
              total: totalWithFee
          ),

          const SizedBox(height: 16),

          // 3. OPTION B: PAY OUTSIDE (The "Manual Path")
          _buildManualPaymentOption(context, host, me),

          const SizedBox(height: 16),

          // 4. OPTION C: PAID DIRECTLY TO RESTAURANT
          _buildDirectPaymentOption(context, host, me),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildInAppPaymentOption(BuildContext context, {required double amount, required double fee, required double total}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        // Light Mode: Use Brand Color bg (Stand out). Dark Mode: Use Surface (Clean).
        color: isDark ? theme.colorScheme.surface : AppColors.lightBerry,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _initiateInAppPayment(amount),
        borderRadius: AppRadius.allMd,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.bolt, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            "Instant Pay",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary
                            )
                        ),
                        const SizedBox(height: 2),
                        Text(
                            "Secure. Instant. Done.",
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7))
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                        "RECOMMENDED",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary)
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),

              // Transparent Math
              _buildMathRow(context, "Bill Amount", amount),
              _buildMathRow(context, "Service Fee (2%)", fee), // Highlighting the low fee
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Charge", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  Text(
                      '${AppConstants.currencySymbol}${total.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualPaymentOption(BuildContext context, Participant host, Participant me) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _markPaidOutside(me, host),
        borderRadius: AppRadius.allMd,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.handshake_outlined, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Pay Outside App",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)
                    ),
                    const SizedBox(height: 2),
                    Text(
                        "Cash, EFT, or Wallet. Requires host confirmation.",
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.disabledColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectPaymentOption(BuildContext context, Participant host, Participant me) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _markPaidDirect(me, host),
        borderRadius: AppRadius.allMd,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.store_outlined, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Paid Restaurant Directly",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)
                    ),
                    const SizedBox(height: 2),
                    Text(
                        "I paid my share at the register. No reimbursement needed.",
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.disabledColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMathRow(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6))),
          Text(
              '${AppConstants.currencySymbol}${value.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6))
          ),
        ],
      ),
    );
  }

  Future<void> _initiateInAppPayment(double amount) async {
    setState(() => _isProcessing = true);
    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final response = await paymentRepo.initiatePayment(
        tableId: widget.tableId,
        amount: amount,
      );
      if (mounted) {
        context.push('/payment-webview/${widget.tableId}', extra: response);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markPaidOutside(Participant me, Participant host) async {
    // Improved Interaction: Bottom Sheet instead of Alert Dialog
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Confirm Manual Payment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                "Did you pay ${AppConstants.currencySymbol}${me.totalOwed.toStringAsFixed(2)} to ${host.displayName}?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkFig),
                      child: const Text("Yes, I Paid"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(paymentRepositoryProvider).markPaidOutside(tableId: widget.tableId);
        // Force refresh to see the pending state
        await _refreshData();
      } catch (e) {
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markPaidDirect(Participant me, Participant host) async {
    // Bottom Sheet confirmation
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Confirm Direct Payment", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                "Did you pay ${AppConstants.currencySymbol}${me.totalOwed.toStringAsFixed(2)} directly to the restaurant?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 8),
              Text(
                "This means ${host.displayName} doesn't need to reimburse you.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkFig),
                      child: const Text("Yes, I Paid"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(paymentRepositoryProvider).markPaidDirect(tableId: widget.tableId);
        // Force refresh to see the pending state
        await _refreshData();
      } catch (e) {
        if (mounted) _showError(e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }
}