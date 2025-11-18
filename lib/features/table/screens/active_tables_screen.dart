import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/table_provider.dart';
import '../models/table_session.dart';

class ActiveTablesScreen extends ConsumerWidget {
  const ActiveTablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTablesAsync = ref.watch(activeTablesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isHostOfActiveTable = ref.watch(isHostOfActiveTableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Tables'),
      ),
      body: activeTablesAsync.when(
        data: (tables) => _buildTablesList(
          context,
          ref,
          tables,
          currentUser?.id,
          isHostOfActiveTable.valueOrNull ?? false,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Error loading tables',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => ref.refresh(activeTablesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablesList(
    BuildContext context,
    WidgetRef ref,
    List<TableSession> tables,
    String? currentUserId,
    bool isHost,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(activeTablesProvider);
      },
      child: CustomScrollView(
        slivers: [
          if (tables.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context, isHost),
            )
          else
            SliverPadding(
              padding: AppSpacing.screenPadding,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < tables.length) {
                      final table = tables[index];
                      final isUserHost = table.hostUserId == currentUserId;
                      return _buildTableCard(
                        context,
                        table,
                        isUserHost,
                      );
                    } else {
                      // Action buttons at the bottom
                      return _buildActionButtons(context, isHost);
                    }
                  },
                  childCount: tables.length + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isHost) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 80,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Active Tables',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You don\'t have any active tables.\nCreate a new table or join an existing one.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildActionButtons(context, isHost),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    TableSession table,
    bool isHost,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.onSurface.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          context.go('/table/${table.id}/claim');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Table icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.table_restaurant,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.title ?? 'Table ${table.code}',
                          style:
                              Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${table.code}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  _buildStatusBadge(context, table.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isHost
                          ? colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1)
                          : colorScheme.surface.withOpacity(isDark ? 0.3 : 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isHost ? 'HOST' : 'PARTICIPANT',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isHost
                                ? colorScheme.primary
                                : colorScheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  const Spacer(),
                  // Created date
                  Text(
                    _formatDate(table.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, TableStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case TableStatus.claiming:
        bgColor = colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1);
        textColor = colorScheme.primary;
        label = 'Claiming';
        break;
      case TableStatus.collecting:
        // Using error color for warning/in-progress state
        bgColor = colorScheme.error.withOpacity(isDark ? 0.2 : 0.1);
        textColor = colorScheme.error;
        label = 'Collecting';
        break;
      case TableStatus.settled:
        // Using primary with different opacity for settled
        bgColor = colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08);
        textColor = colorScheme.primary;
        label = 'Settled';
        break;
      case TableStatus.cancelled:
        bgColor = colorScheme.onSurface.withOpacity(isDark ? 0.15 : 0.08);
        textColor = colorScheme.onSurface.withOpacity(0.6);
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isHost) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isHost)
          ElevatedButton.icon(
            onPressed: () {
              context.push('/table/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create New Table'),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You can only host one table at a time. Close your current table to create a new one.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () {
            context.push('/table/join');
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Join Existing Table'),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}
