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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(activeTablesProvider);
    });
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

    // Logic: Check if host of any active table
    final activeTablesList = activeTablesAsync.valueOrNull ?? [];
    final isHost = activeTablesList.any((t) =>
    t.hostUserId == currentUser?.id &&
        (t.status == TableStatus.claiming ||
            t.status == TableStatus.collecting));

    return Scaffold(
      // FIX: Use theme background (adapts to Light Crust / Dark Plum)
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: _buildActionDeck(context, isHost),
              ),
            ),

            // 3. Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.history_toggle_off,
                        size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 8),
                    Text(
                      "ACTIVE SESSIONS",
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
                    .where((t) =>
                t.status == TableStatus.claiming ||
                    t.status == TableStatus.collecting)
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
                    child:
                    CircularProgressIndicator(color: theme.colorScheme.primary)),
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
    final theme = Theme.of(context);
    // Keep brand gradient, but ensure text/icons are always light on top of it
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 14),
        title: const Text(
          'pyble',
          style: TextStyle(
            fontFamily: 'Quip',
            fontWeight: FontWeight.normal,
            letterSpacing: 1.5,
            color: AppColors.snow, // Always white on the Berry brand color
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

  Widget _buildActionDeck(BuildContext context, bool isHost) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // CARD 1: Host (Filled Brand Color)
        Expanded(
          child: _ActionCard(
            title: "Host Table",
            subtitle: "Create New",
            icon: Icons.add_business,
            color: theme.colorScheme.primary,
            isOutlined: false,
            isDisabled: isHost,
            onTap: () => context.push('/table/create'),
          ),
        ),
        const SizedBox(width: 12),
        // CARD 2: Join (Surface Color with Border)
        Expanded(
          child: _ActionCard(
            title: "Join Table",
            subtitle: "Scan Code",
            icon: Icons.qr_code_scanner,
            color: theme.colorScheme.onSurface, // Icon color
            isOutlined: true,
            onTap: () => context.push('/table/join'),
          ),
        ),
      ],
    );
  }
}

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
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Logic for Colors based on Theme + Outline status
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
        // No shadow in dark mode, standard shadow in light
        shadowColor: isDark ? Colors.transparent : color.withOpacity(0.3),
        child: InkWell(
          onTap: isDisabled
              ? () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text("You are already hosting a table."),
              backgroundColor: theme.colorScheme.error,
            ));
          }
              : onTap,
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

class _TicketCard extends StatelessWidget {
  final TableSession table;
  final String? currentUserId;

  const _TicketCard({required this.table, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHost = table.hostUserId == currentUserId;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Adapts to Snow vs Dark Surface
        borderRadius: AppRadius.allMd,
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
                        ? theme.colorScheme.error // Warm Spice
                        : theme.colorScheme.primary, // Deep Berry
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
                Icon(Icons.restaurant, size: 40, color: onSurface.withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "Ready to Order?",
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              "Start a new table or join your friends to split the bill instantly.",
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