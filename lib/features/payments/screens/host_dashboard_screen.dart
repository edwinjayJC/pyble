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
    // Hard refresh to prevent cached "Owing" state
    return ref.refresh(currentTableProvider.notifier).loadTable(widget.tableId);
  }


  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(currentTableProvider);
    final theme = Theme.of(context);

    return Scaffold(
      // FIX: Use theme background (Light Crust vs Dark Plum)
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Collection Dashboard',
          style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
            onSelected: (value) {
              if (value == 'unlock') _unlockBill();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'unlock',
                child: Row(
                  children: [
                    Icon(Icons.lock_open, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Unlock Bill',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
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
            color: theme.colorScheme.primary,
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // 1. THE FINANCIAL COCKPIT (LEDGER)
                  _buildLedgerSummary(context, participants),

                  const SizedBox(height: AppSpacing.xl),

                  // 2. MY TAB (Host's Liability)
                  Text(
                    "MY TAB",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildHostCard(context, host),

                  const SizedBox(height: AppSpacing.xl),

                  // 3. GUEST LIST
                  Text(
                    "GUEST REIMBURSEMENTS",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (guests.isEmpty)
                    _buildEmptyGuestsState(context)
                  else
                    ...guests.map((g) => _buildGuestRow(context, g)),

                  const SizedBox(height: 40),

                  // 4. SETTLE BUTTON
                  _buildSettleButton(context, participants),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  // === 1. The Ledger Summary ===
  Widget _buildLedgerSummary(BuildContext context, List<Participant> participants) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    double collected = 0;
    double pending = 0;
    double outstanding = 0;

    for (var p in participants) {
      if (p.paymentStatus == PaymentStatus.paid) {
        collected += p.totalOwed;
      } else if (p.paymentStatus == PaymentStatus.pendingConfirmation ||
                 p.paymentStatus == PaymentStatus.pendingDirectConfirmation) {
        pending += p.totalOwed;
      } else {
        outstanding += p.totalOwed;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // FIX: Use Surface for adaptive background
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.allLg,
        // Add border in dark mode for visibility
        border: isDark ? Border.all(color: theme.dividerColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Collected
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "COLLECTED",
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${AppConstants.currencySymbol}${collected.toStringAsFixed(2)}",
                style: const TextStyle(color: AppColors.lushGreen, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          Container(width: 1, height: 40, color: theme.dividerColor),

          // Right: Missing
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "MISSING",
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1
                ),
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
                      // Use Theme Text Color for 0, Spice for >0
                        color: (pending + outstanding) == 0
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : AppColors.warmSpice,
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
  Widget _buildHostCard(BuildContext context, Participant host) {
    final theme = Theme.of(context);
    final isPaid = host.paymentStatus == PaymentStatus.paid;

    return Container(
      decoration: BoxDecoration(
        // FIX: Use Surface
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(
            color: isPaid ? AppColors.lushGreen.withOpacity(0.3) : theme.dividerColor
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: isPaid ? AppColors.lightGreen : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
              Icons.person,
              color: isPaid ? AppColors.lushGreen : theme.colorScheme.onSurface
          ),
        ),
        title: Text(
            "My Items",
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)
        ),
        subtitle: Text(
          isPaid ? "Accounted for" : "Deduct from total bill",
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
              backgroundColor: theme.colorScheme.onSurface, // Black/White based on theme
              foregroundColor: theme.colorScheme.surface, // Inverse text
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: const Text("Account", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGuestsState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 32, color: theme.disabledColor),
          const SizedBox(height: 8),
          Text("No guests yet", style: TextStyle(color: theme.disabledColor)),
        ],
      ),
    );
  }

  // === 3. Guest Row ===
  Widget _buildGuestRow(BuildContext context, Participant guest) {
    final theme = Theme.of(context);
    Color statusColor;
    IconData statusIcon;
    String statusText;

    bool showActionButton = false;
    bool isManualForcePay = false;

    bool isDirectPayment = false;

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

      case PaymentStatus.pendingDirectConfirmation:
        statusColor = AppColors.warmSpice;
        statusIcon = Icons.store;
        statusText = "Direct Pay?";
        showActionButton = true;
        isDirectPayment = true;
        break;

      case PaymentStatus.owing:
      default:
        statusColor = theme.colorScheme.onSurface.withOpacity(0.4);
        statusIcon = Icons.access_time;
        statusText = "Owes";
        showActionButton = true;
        isManualForcePay = true;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        border: showActionButton && !isManualForcePay
            ? Border.all(color: isDirectPayment ? AppColors.warmSpice : AppColors.warmSpice, width: 1.5)
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
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: guest.avatarUrl == null
                  ? Text(guest.initials, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))
                  : null,
            ),
            if (guest.paymentStatus == PaymentStatus.paid)
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.lushGreen, size: 16),
                ),
              ),
          ],
        ),
        title: Text(
          guest.displayName,
          style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
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
            onPressed: _isProcessing ? null : () => _confirmPayment(guest, isManualForce: isManualForcePay, isDirectPayment: isDirectPayment),
            style: ElevatedButton.styleFrom(
              // Manual Pay = Neutral Button. Pending/Direct = Action Button.
              backgroundColor: isManualForcePay ? theme.colorScheme.onSurface : AppColors.lushGreen,
              foregroundColor: isManualForcePay ? theme.colorScheme.surface : Colors.white,
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
            color: guest.paymentStatus == PaymentStatus.paid ? AppColors.lushGreen : theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // === 4. Settle Button ===
  Widget _buildSettleButton(BuildContext context, List<Participant> participants) {
    final theme = Theme.of(context);
    final allPaid = participants.every((p) => p.paymentStatus == PaymentStatus.paid);

    return Opacity(
      opacity: allPaid ? 1.0 : 0.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: allPaid ? _settleTable : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
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

  Future<void> _confirmPayment(Participant p, {bool isSelf = false, bool isManualForce = false, bool isDirectPayment = false}) async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);

      if (isSelf || isManualForce) {
        await paymentRepo.markPaidOutside(tableId: widget.tableId);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await paymentRepo.confirmPayment(
        tableId: widget.tableId,
        participantUserId: p.userId,
      );

      await _refreshData();

      if (mounted) {
        String message;
        if (isSelf) {
          message = "Your share accounted for.";
        } else if (isDirectPayment) {
          message = "Direct payment confirmed from ${p.displayName}";
        } else {
          message = "Payment confirmed from ${p.displayName}";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.lushGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _settleTable() async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Out Table"),
        content: const Text("This will archive the bill and move it to history. Everyone has paid."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
            child: Text("Archive", style: TextStyle(color: theme.colorScheme.onPrimary)),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: theme.colorScheme.error),
          );
        }
      }
    }
  }

  Future<void> _cancelTable() async {
    final theme = Theme.of(context);

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
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
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
            SnackBar(content: Text('Error: $e'), backgroundColor: theme.colorScheme.error),
          );
        }
      }
    }
  }

  Future<void> _unlockBill() async {
    final theme = Theme.of(context);
    final shouldUnlock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Bill?'),
        content: const Text(
          'Unlocking returns the table to the claim stage so guests can make more changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep Locked',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Unlock Bill'),
          ),
        ],
      ),
    );

    if (shouldUnlock != true) return;

    try {
      await ref.read(currentTableProvider.notifier).unlockTable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bill unlocked'),
            backgroundColor: theme.colorScheme.primary,
          ),
        );
        context.go('/table/${widget.tableId}/claim');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unlocking bill: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }
}
