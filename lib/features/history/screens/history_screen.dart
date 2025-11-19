import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers/supabase_provider.dart';

// Feature Imports
import '../../table/providers/table_provider.dart';
import '../../table/models/table_session.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyTablesAsync = ref.watch(historyTablesProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.lightCrust,
      appBar: AppBar(
        title: const Text(
            'Past Sessions',
            style: TextStyle(color: AppColors.darkFig, fontWeight: FontWeight.bold)
        ),
        backgroundColor: AppColors.lightCrust,
        elevation: 0,
        centerTitle: true,
        // THE FIX: Explicit Back Button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkFig),
          onPressed: () => context.pop(),
        ),
      ),
      body: historyTablesAsync.when(
        data: (historyTables) {
          // Sort by most recent first
          final sortedTables = List<TableSession>.from(historyTables)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (sortedTables.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            color: AppColors.deepBerry,
            onRefresh: () async => ref.refresh(historyTablesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sortedTables.length,
              itemBuilder: (context, index) {
                final table = sortedTables[index];
                final isUserHost = table.hostUserId == currentUser?.id;
                return _buildHistoryItem(context, table, isUserHost);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.deepBerry)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: AppColors.darkFig.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('Could not load history', style: TextStyle(color: AppColors.darkFig.withOpacity(0.5))),
              TextButton(
                onPressed: () => ref.refresh(historyTablesProvider),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      ),
    );
  }

  // === 1. The "Journal Entry" Item ===
  Widget _buildHistoryItem(BuildContext context, TableSession table, bool isHost) {
    final isSettled = table.status == TableStatus.settled;

    // Visual Logic
    final statusColor = isSettled ? AppColors.lushGreen : AppColors.darkFig.withOpacity(0.4);
    final statusIcon = isSettled ? Icons.receipt_long : Icons.cancel_presentation;
    final bgColor = AppColors.snow;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkFig.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/table/${table.id}/claim'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // A. The Icon Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),

                const SizedBox(width: 16),

                // B. The Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Role
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              table.title ?? 'Table ${table.code}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkFig,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isHost) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.deepBerry.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "HOST",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepBerry
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Date & Status Text
                      Row(
                        children: [
                          Text(
                            _formatDate(table.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkFig.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.darkFig.withOpacity(0.3), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            isSettled ? "Completed" : "Cancelled",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // C. Chevron
                Icon(Icons.chevron_right, color: AppColors.paleGray.withOpacity(0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === 2. Empty State ===
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.snow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepBerry.withOpacity(0.05),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(Icons.history_edu, size: 48, color: AppColors.deepBerry.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No History Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.darkFig,
                  fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed dining sessions will appear here safe and sound.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.darkFig.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}