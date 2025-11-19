import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
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
import '../../table/repository/table_repository.dart';
import '../repository/payment_repository.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  final String tableId;

  const HostDashboardScreen({super.key, required this.tableId});

  @override
  ConsumerState<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
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
    // LOGIC UPGRADE: Use refresh() to force a hard DB fetch.
    // This prevents the UI from showing cached "Owing" states after a confirmation.
    return ref.refresh(currentTableProvider.notifier).loadTable(widget.tableId);
  }


  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(currentTableProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.lightCrust,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Collection Dashboard',
          style: TextStyle(color: AppColors.darkFig, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.darkFig),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.darkFig),
            onSelected: (value) {
              if (value == 'cancel') _cancelTable();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: AppColors.warmSpice, size: 20),
                    SizedBox(width: 8),
                    Text('Cancel Table', style: TextStyle(color: AppColors.warmSpice)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: tableAsync.when(
        data: (tableData) {
          if (tableData == null) return const Center(child: Text('No Data'));

          final participants = tableData.participants;
          final currentUser = ref.watch(currentUserProvider);

          // Find Host (Me)
          final host = participants.firstWhere(
                (p) => p.userId == currentUser?.id,
            orElse: () => participants.first,
          );

          // Separate guests from host
          final guests = participants.where((p) => p.userId != host.userId).toList();

          return RefreshIndicator(
            color: AppColors.deepBerry,
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // 1. THE FINANCIAL COCKPIT (LEDGER)
                  _buildLedgerSummary(participants),

                  const SizedBox(height: AppSpacing.xl),

                  // 2. MY TAB (Host's Liability)
                  Text(
                    "MY TAB",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.darkFig.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildHostCard(host),

                  const SizedBox(height: AppSpacing.xl),

                  // 3. GUEST LIST
                  Text(
                    "GUEST REIMBURSEMENTS",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.darkFig.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (guests.isEmpty)
                    _buildEmptyGuestsState()
                  else
                    ...guests.map((g) => _buildGuestRow(g)),

                  const SizedBox(height: 40),

                  // 4. SETTLE BUTTON
                  _buildSettleButton(participants),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.deepBerry)),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  // === 1. The Ledger Summary (Dark, High Contrast) ===
  Widget _buildLedgerSummary(List<Participant> participants) {
    double collected = 0;
    double pending = 0;
    double outstanding = 0;

    for (var p in participants) {
      if (p.paymentStatus == PaymentStatus.paid) {
        collected += p.totalOwed;
      } else if (p.paymentStatus == PaymentStatus.pendingConfirmation) {
        pending += p.totalOwed;
      } else {
        outstanding += p.totalOwed;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkFig, // Dark background for professional look
        borderRadius: AppRadius.allLg,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkFig.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Collected (Good News)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "COLLECTED",
                style: TextStyle(color: AppColors.snow.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                "${AppConstants.currencySymbol}${collected.toStringAsFixed(2)}",
                style: const TextStyle(color: AppColors.lushGreen, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          Container(width: 1, height: 40, color: AppColors.snow.withOpacity(0.2)),

          // Right: Missing (Bad News)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "MISSING",
                style: TextStyle(color: AppColors.snow.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (pending > 0)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.priority_high, color: AppColors.warmSpice, size: 18),
                    ),
                  Text(
                    "${AppConstants.currencySymbol}${(pending + outstanding).toStringAsFixed(2)}",
                    style: TextStyle(
                        color: (pending + outstanding) == 0 ? AppColors.snow : AppColors.warmSpice,
                        fontSize: 28,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === 2. Host "My Tab" Card ===
  Widget _buildHostCard(Participant host) {
    final isPaid = host.paymentStatus == PaymentStatus.paid;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: isPaid ? AppColors.lushGreen.withOpacity(0.3) : AppColors.paleGray),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: isPaid ? AppColors.lightGreen : AppColors.lightCrust,
          child: Icon(Icons.person, color: isPaid ? AppColors.lushGreen : AppColors.darkFig),
        ),
        title: const Text("My Items", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkFig)),
        subtitle: Text(
          isPaid ? "Accounted for" : "Deduct from total bill",
          style: TextStyle(fontSize: 12, color: AppColors.darkFig.withOpacity(0.6)),
        ),
        trailing: isPaid
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
          child: const Text("Done", style: TextStyle(color: AppColors.lushGreen, fontWeight: FontWeight.bold, fontSize: 12)),
        )
            : SizedBox(
          width: 120,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : () => _confirmPayment(host, isSelf: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkFig,
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: const Text("Account", style: TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGuestsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.snow.withOpacity(0.5),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: AppColors.paleGray, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 32, color: AppColors.darkFig.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text("No guests yet", style: TextStyle(color: AppColors.darkFig.withOpacity(0.5))),
        ],
      ),
    );
  }

  // === 3. Guest Row (With Force Pay Logic) ===
  Widget _buildGuestRow(Participant guest) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    // LOGIC: Allow host to act on 'Pending' AND 'Owing' states
    bool showActionButton = false;
    bool isManualForcePay = false;

    switch (guest.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = AppColors.lushGreen;
        statusIcon = Icons.check_circle;
        statusText = "Settled";
        break;

      case PaymentStatus.pendingConfirmation:
        statusColor = AppColors.warmSpice;
        statusIcon = Icons.pending;
        statusText = "Confirm?";
        showActionButton = true;
        break;

      case PaymentStatus.owing:
      default:
        statusColor = AppColors.darkFig.withOpacity(0.4);
        statusIcon = Icons.access_time;
        statusText = "Owes";
        // LAUNCH FEATURE: Allow Host to manually mark them as paid
        // even if the guest hasn't tapped anything.
        showActionButton = true;
        isManualForcePay = true;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: AppRadius.allMd,
        // Highlight pending confirmation with a border
        border: showActionButton && !isManualForcePay
            ? Border.all(color: AppColors.warmSpice, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: guest.avatarUrl != null ? NetworkImage(guest.avatarUrl!) : null,
              backgroundColor: AppColors.paleGray,
              child: guest.avatarUrl == null
                  ? Text(guest.initials, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkFig))
                  : null,
            ),
            if (guest.paymentStatus == PaymentStatus.paid)
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.snow, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.lushGreen, size: 16),
                ),
              ),
          ],
        ),
        title: Text(
          guest.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkFig),
        ),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 12, color: statusColor),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: showActionButton
            ? SizedBox(
          width: 100,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : () => _confirmPayment(guest, isManualForce: isManualForcePay),
            style: ElevatedButton.styleFrom(
              backgroundColor: isManualForcePay ? AppColors.darkFig : AppColors.lushGreen,
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: Text(
                isManualForcePay ? "Mark Paid" : "Confirm",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
            ),
          ),
        )
            : Text(
          "${AppConstants.currencySymbol}${guest.totalOwed.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: guest.paymentStatus == PaymentStatus.paid ? AppColors.lushGreen : AppColors.darkFig,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // === 4. Settle Button ===
  Widget _buildSettleButton(List<Participant> participants) {
    final allPaid = participants.every((p) => p.paymentStatus == PaymentStatus.paid);

    return Opacity(
      opacity: allPaid ? 1.0 : 0.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: allPaid ? _settleTable : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepBerry,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: allPaid ? 4 : 0,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.done_all),
              const SizedBox(width: 8),
              Text(
                allPaid ? "Close Out & Archive" : "Waiting for Payments...",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === ACTIONS ===

  Future<void> _confirmPayment(Participant p, {bool isSelf = false, bool isManualForce = false}) async {
    HapticFeedback.mediumImpact(); // Touch feedback
    setState(() => _isProcessing = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);

      // FIX: RACE CONDITION PREVNETION
      // If the host is paying themselves OR forcing a payment for a guest,
      // we must FIRST mark it as "Pending" (Paid Outside) on the backend.
      if (isSelf || isManualForce) {
        await paymentRepo.markPaidOutside(tableId: widget.tableId);
        // Tiny delay ensures the database trigger finishes before we confirm
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Now perform the confirmation
      await paymentRepo.confirmPayment(
        tableId: widget.tableId,
        participantUserId: p.userId,
      );

      // HARD REFRESH: Use ref.refresh to force fresh data from DB
      // This ensures the UI doesn't get stuck showing the old state
      await _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSelf ? "Your share accounted for." : "Payment confirmed from ${p.displayName}"),
            backgroundColor: AppColors.lushGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.warmSpice),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _settleTable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Out Table"),
        content: const Text("This will archive the bill and move it to history. Everyone has paid."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppColors.darkFig)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepBerry),
            child: const Text("Archive"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(currentTableProvider.notifier).settleTable();
        if (mounted) context.go('/home');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.warmSpice),
          );
        }
      }
    }
  }

  Future<void> _cancelTable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Table?'),
        content: const Text(
          'Are you sure you want to cancel this table? '
              'All participants will be notified and this action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmSpice,
            ),
            child: const Text('Yes, Cancel Table'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final tableRepo = ref.read(tableRepositoryProvider);
        await tableRepo.cancelTable(widget.tableId);
        if (mounted) context.go('/home');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.warmSpice),
          );
        }
      }
    }
  }
}