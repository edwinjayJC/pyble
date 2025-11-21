import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/app_drawer.dart';

// Feature Imports
import '../../table/providers/table_provider.dart';
import '../../table/models/table_session.dart';
import '../../table/repository/table_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Initial fetch & Start Polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(activeTablesProvider);
      _startPolling();
    });
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(activeTablesProvider);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _refreshData() async {
    ref.invalidate(activeTablesProvider);
    await ref.read(activeTablesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final activeTablesAsync = ref.watch(activeTablesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. The Branded Header
            _buildSliverAppBar(context),

            // 2. The "Action Deck"
            // UPDATE: 'isHost' restriction removed. Users can host multiple tables.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: _buildActionDeck(context),
              ),
            ),

            // 3. Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 8),
                    Text(
                      "YOUR EVENTS",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. The Live Ticket List
            activeTablesAsync.when(
              data: (tables) {
                final visibleTables = tables
                    .where(
                      (t) =>
                  t.status == TableStatus.claiming ||
                      t.status == TableStatus.collecting ||
                      t.status == TableStatus.pendingPayments ||
                      t.status == TableStatus.readyForHostSettlement ||
                      t.status == TableStatus.open,
                )
                    .toList();

                if (visibleTables.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyStateIllustration(),
                  );
                }

                return SliverPadding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return _TicketCard(
                          table: visibleTables[index],
                          currentUserId: currentUser?.id,
                        );
                      },
                      childCount: visibleTables.length,
                    ),
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _buildErrorState(context, e),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Tables',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(activeTablesProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.deepBerry, // Keep Brand Color Fixed
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 14),
        title: const Text(
          'pyble',
          style: TextStyle(
            fontFamily: 'Quip',
            fontWeight: FontWeight.normal,
            letterSpacing: 1.5,
            color: AppColors.snow,
            fontSize: 32,
            shadows: [
              Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB70043), // Brand Berry
                Color(0xFFD9275D), // Brand Lighter
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white.withOpacity(0.05)),
              ),
            ],
          ),
        ),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.snow),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: AppColors.snow),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildActionDeck(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // CARD 1: Host
        Expanded(
          child: _ActionCard(
            title: "Host Table",
            subtitle: "Plan Event",
            icon: Icons.add_business,
            color: theme.colorScheme.primary,
            isOutlined: false,
            isDisabled: false, // UPDATE: Always enabled now
            onTap: () => context.push('/table/create'),
          ),
        ),
        const SizedBox(width: 12),
        // CARD 2: Join
        Expanded(
          child: _ActionCard(
            title: "Join Table",
            subtitle: "Scan Code",
            icon: Icons.qr_code_scanner,
            color: theme.colorScheme.onSurface,
            isOutlined: true,
            isDisabled: false,
            onTap: () => context.push('/table/join'),
          ),
        ),
      ],
    );
  }
}

// === Sub-Widgets ===

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isOutlined;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isOutlined,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isOutlined
        ? theme.colorScheme.surface
        : theme.colorScheme.primary;

    final textColor = isOutlined
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onPrimary;

    final subTextColor = isOutlined
        ? theme.colorScheme.onSurface.withOpacity(0.6)
        : theme.colorScheme.onPrimary.withOpacity(0.8);

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Material(
        color: cardBg,
        borderRadius: AppRadius.allLg,
        elevation: isOutlined ? 0 : 4,
        shadowColor: isDark ? Colors.transparent : color.withOpacity(0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.allLg,
          child: Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.allLg,
              border: isOutlined
                  ? Border.all(color: theme.dividerColor, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOutlined
                        ? theme.dividerColor.withOpacity(0.5)
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: isOutlined ? color : Colors.white, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: subTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  final TableSession table;
  final String? currentUserId;

  const _TicketCard({required this.table, this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isHost = table.hostUserId == currentUserId;
    final isDark = theme.brightness == Brightness.dark;

    // UPDATE: Dismissible re-enabled for removal logic
    return Dismissible(
      key: Key(table.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          // Red for Host (Cancel), Orange for Guest (Leave)
          color: isHost ? theme.colorScheme.error : AppColors.warmSpice,
          borderRadius: AppRadius.allMd,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHost ? Icons.cancel_presentation : Icons.exit_to_app,
              color: Colors.white, // Text always white on Error/Warning colors
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              isHost ? 'Cancel' : 'Leave',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (isHost) {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Event?'),
              content: Text(
                'This will permanently remove "${table.title ?? "Table ${table.code}"}" for everyone. This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Keep Event', style: TextStyle(color: theme.colorScheme.onSurface)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Text('Cancel Event'),
                ),
              ],
            ),
          );
        } else {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Leave Table?'),
              content: Text(
                'Are you sure you want to leave "${table.title ?? "Table ${table.code}"}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Stay', style: TextStyle(color: theme.colorScheme.onSurface)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmSpice,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Leave Table'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) async {
        try {
          if (isHost) {
            final repository = ref.read(tableRepositoryProvider);
            await repository.cancelTable(table.id);
            ref.invalidate(activeTablesProvider);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Event "${table.title ?? table.code}" cancelled'),
                  backgroundColor: theme.colorScheme.primary, // Primary color for success/info
                ),
              );
            }
          } else {
            await ref.read(currentTableProvider.notifier).leaveTable(table.id);
            ref.invalidate(activeTablesProvider);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Left "${table.title ?? table.code}"'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            }
          }
        } catch (e) {
          // Restore the item on error
          ref.invalidate(activeTablesProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to remove: $e'),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      },
      child: _buildCard(context, theme, isDark, isHost),
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme, bool isDark, bool isHost) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        // Border for definition in Dark Mode
        border: isDark ? Border.all(color: theme.dividerColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/table/${table.id}/claim'),
          borderRadius: AppRadius.allMd,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 1. Status Strip
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: table.status == TableStatus.collecting
                        ? theme.colorScheme.error // Warm Spice (Attention)
                        : theme.colorScheme.primary, // Deep Berry (Active)
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(width: 16),

                // 3. Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.title ?? "Table ${table.code}",
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isHost) _buildTag(context, "HOST", theme.colorScheme.primary),
                          if (table.status == TableStatus.collecting)
                            _buildTag(context, "COLLECTING", theme.colorScheme.error),
                          Text(
                            " • ${table.code}",
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Icon(Icons.chevron_right, color: theme.disabledColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _EmptyStateIllustration extends StatelessWidget {
  const _EmptyStateIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1)),
                Icon(Icons.calendar_month, size: 40, color: onSurface.withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "No Upcoming Events",
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              "Plan a dinner or join a friend's table to get started.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: onSurface.withOpacity(0.6),
                  height: 1.5),
            ),
            const SizedBox(height: 40),
            Column(
              children: [
                Text("Use buttons above",
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onSurface.withOpacity(0.3))),
                Icon(Icons.arrow_upward,
                    size: 16, color: onSurface.withOpacity(0.3)),
              ],
            )
          ],
        ),
      ),
    );
  }
}