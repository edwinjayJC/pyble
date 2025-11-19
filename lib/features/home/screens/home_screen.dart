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
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(activeTablesProvider);
    });
  }

  Future<void> _refreshData() async {
    ref.invalidate(activeTablesProvider);
    // Wait for the provider to finish loading
    await ref.read(activeTablesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final activeTablesAsync = ref.watch(activeTablesProvider);
    final currentUser = ref.watch(currentUserProvider);

    // LOGIC FIX: Calculate 'isHost' directly from the data to prevent desync.
    // We check if the current user is the host of ANY table that is actively 'claiming' or 'collecting'.
    final activeTablesList = activeTablesAsync.valueOrNull ?? [];
    final isHost = activeTablesList.any((t) =>
        t.hostUserId == currentUser?.id &&
        (t.status == TableStatus.claiming ||
            t.status == TableStatus.collecting));

    return Scaffold(
      backgroundColor: AppColors.lightCrust,
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.deepBerry,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. The Branded Header (With Quip Font)
            _buildSliverAppBar(context),

            // 2. The "Action Deck" (Host/Join Buttons)
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
                    const Icon(Icons.history_toggle_off,
                        size: 16, color: AppColors.dusk),
                    const SizedBox(width: 8),
                    Text(
                      "ACTIVE SESSIONS",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.dusk,
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
                // Filter for UI: Only show Claiming or Collecting (Active)
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
              loading: () => const SliverFillRemaining(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.deepBerry)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: AppColors.warmSpice),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to Load Tables',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkFig,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.darkFig.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(activeTablesProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepBerry,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Padding for scrolling past FABs or bottom bars
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // === 1. The Modern App Bar (With Quip Font) ===
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.deepBerry,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 14),
        title: const Text(
          'pyble',
          style: TextStyle(
            fontFamily: 'Quip', // FONT FIX: Reverted to Brand Font
            fontWeight: FontWeight.normal,
            letterSpacing: 1.5,
            color: AppColors.snow,
            fontSize: 32,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFB70043), // Original Brand Color
                const Color(0xFFD9275D), // Lighter Gradient
              ],
            ),
          ),
          child: Stack(
            children: [
              // Subtle texture decoration
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

  // === 2. The Action Deck ===
  Widget _buildActionDeck(BuildContext context, bool isHost) {
    return Row(
      children: [
        // CARD 1: Host
        Expanded(
          child: _ActionCard(
            title: "Host Table",
            subtitle: "Create New",
            icon: Icons.add_business,
            color: AppColors.deepBerry,
            isOutlined: false,
            isDisabled: isHost, // Controlled by local logic now
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
            color: AppColors.darkFig,
            isOutlined: true,
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
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Material(
        color: isOutlined ? AppColors.snow : color,
        borderRadius: AppRadius.allLg,
        elevation: isOutlined ? 0 : 4,
        shadowColor: color.withOpacity(0.3),
        child: InkWell(
          onTap: isDisabled
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "You are already hosting a table. Close it to start a new one."),
                    backgroundColor: AppColors.warmSpice,
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
                  ? Border.all(color: AppColors.paleGray, width: 1.5)
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
                        ? AppColors.paleGray.withOpacity(0.3)
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
                        color: isOutlined
                            ? AppColors.darkFig.withOpacity(0.5)
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOutlined ? AppColors.darkFig : Colors.white,
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
    final isHost = table.hostUserId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: AppRadius.allMd,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkFig.withOpacity(0.05),
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
                        ? AppColors.warmSpice
                        : AppColors.deepBerry,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightCrust,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.receipt_long, color: AppColors.darkFig),
                ),
                const SizedBox(width: 16),

                // 3. Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.title ?? "Table ${table.code}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.darkFig),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isHost) _buildTag("HOST", AppColors.deepBerry),
                          if (table.status == TableStatus.collecting)
                            _buildTag("COLLECTING", AppColors.warmSpice),
                          Text(
                            " • ${table.code}",
                            style: TextStyle(
                                color: AppColors.darkFig.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: AppColors.paleGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _EmptyStateIllustration extends StatelessWidget {
  const _EmptyStateIllustration();

  @override
  Widget build(BuildContext context) {
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
                    backgroundColor: AppColors.deepBerry.withOpacity(0.05)),
                const Icon(Icons.restaurant, size: 40, color: AppColors.dusk),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Ready to Order?",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkFig),
            ),
            const SizedBox(height: 8),
            Text(
              "Start a new table or join your friends to split the bill instantly.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.darkFig.withOpacity(0.6),
                  height: 1.5),
            ),
            const SizedBox(height: 40),
            Column(
              children: [
                Text("Use buttons above",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkFig.withOpacity(0.3))),
                Icon(Icons.arrow_upward,
                    size: 16, color: AppColors.darkFig.withOpacity(0.3)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
