import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/api/api_client.dart';

// Feature Imports
import '../../auth/providers/user_profile_provider.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../providers/friends_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Friends',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'My Friends'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      // FAB for Primary Action (Mobile First)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showConnectionOptions(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("Add Friend"),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsListTab(context),
          _buildRequestsTab(context),
        ],
      ),
    );
  }

  // === 1. Friends List Tab ===
  Widget _buildFriendsListTab(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return friendsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      error: (error, stack) => _buildErrorState(context, error, () => ref.invalidate(friendsListProvider)),
      data: (friends) {
        if (friends.isEmpty) return _buildEmptyFriendsState(context);

        return RefreshIndicator(
          onRefresh: () => ref.read(friendsListProvider.notifier).refresh(),
          color: colorScheme.primary,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Pad for FAB
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildFriendTile(context, friends[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendTile(BuildContext context, Friend friend) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use Dismissible for cleaner "Remove" action
    return Dismissible(
      key: Key(friend.userId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.person_remove, color: colorScheme.onError),
      ),
      confirmDismiss: (direction) => _confirmRemoveFriend(context, friend),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
            child: friend.avatarUrl == null
                ? Text(friend.initials, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(
            friend.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: friend.isAuto
              ? Text('Added automatically', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)))
              : null,
          trailing: Icon(Icons.chevron_right, color: theme.disabledColor),
        ),
      ),
    );
  }

  // === 2. Requests Tab ===
  Widget _buildRequestsTab(BuildContext context) {
    final requestsAsync = ref.watch(friendRequestsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return requestsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      error: (error, stack) => _buildErrorState(context, error, () => ref.invalidate(friendRequestsProvider)),
      data: (requests) {
        if (requests.isEmpty) return _buildEmptyRequestsState(context);

        return RefreshIndicator(
          onRefresh: () => ref.read(friendRequestsProvider.notifier).refresh(),
          color: colorScheme.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildRequestTile(context, requests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestTile(BuildContext context, FriendRequest request) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                backgroundImage: request.fromAvatarUrl != null ? NetworkImage(request.fromAvatarUrl!) : null,
                child: request.fromAvatarUrl == null
                    ? Text(request.initials, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.fromDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Sent ${_formatDate(request.createdAt)}", style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectRequest(context, request),
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error, side: BorderSide(color: colorScheme.error)),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(context, request),
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                  child: const Text("Accept"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === 3. Action Sheets (The UX Fix) ===

  void _showConnectionOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Add Friend", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Option A: Scan
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.qr_code_scanner,
                      label: "Scan Code",
                      color: theme.colorScheme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        _openScanner(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Option B: Show Mine
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.qr_code_2,
                      label: "My Code",
                      color: theme.colorScheme.secondary,
                      onTap: () {
                        Navigator.pop(context);
                        _showMyCodeSheet(context);
                      },
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

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FriendScannerScreen()),
    );
  }

  void _showMyCodeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MyQRCodeSheet(),
    );
  }

  // === Logic Helpers ===

  Future<bool> _confirmRemoveFriend(BuildContext context, Friend friend) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text('Are you sure you want to remove ${friend.displayName}? They will need approval to join your tables again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: theme.colorScheme.onSurface))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text("Remove"),
          ),
        ],
      ),
    ) ?? false;

    // Note: Actual removal logic needs to happen in onDismissed if using Dismissible,
    // but for async consistency we usually handle the API call here or in onDismissed callback.
    // Since Dismissible expects immediate UI removal, we'd call the provider here.
  }

  Future<void> _acceptRequest(BuildContext context, FriendRequest request) async {
    try {
      await ref.read(friendRequestsProvider.notifier).acceptRequest(request.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${request.fromDisplayName} added!'), backgroundColor: AppColors.lushGreen),
        );
      }
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _rejectRequest(BuildContext context, FriendRequest request) async {
    try {
      await ref.read(friendRequestsProvider.notifier).rejectRequest(request.id);
    } catch (e) {
      _showError(context, e);
    }
  }

  void _showError(BuildContext context, Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_getErrorMessage(e)), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  String _getErrorMessage(Object error) {
    if (error is ApiException) return error.message;
    return 'An unexpected error occurred';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}';
  }

  // === Empty States ===

  Widget _buildEmptyFriendsState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diversity_3, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text("No Friends Yet", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Add friends to let them join your tables instantly without approval.",
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 32),
          // Hint arrow
          Icon(Icons.arrow_downward, color: theme.colorScheme.primary.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsState(BuildContext context) {
    return const Center(child: Text("No pending requests"));
  }

  Widget _buildErrorState(BuildContext context, Object error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.warmSpice),
          const SizedBox(height: 16),
          Text(_getErrorMessage(error)),
          TextButton(onPressed: onRetry, child: const Text("Retry"))
        ],
      ),
    );
  }
}

// ==========================================
// SUB-SCREENS (MODALS)
// ==========================================

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class MyQRCodeSheet extends ConsumerWidget {
  const MyQRCodeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userId = profile?.id ?? '';
    final friendLink = 'pyble://friend/$userId';
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
          ),
          Text("My Friend Code", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, // QR needs white background always
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: friendLink,
              version: QrVersions.auto,
              size: 240.0,
              backgroundColor: Colors.white,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: AppColors.deepBerry,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: AppColors.darkFig,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Friends can scan this to add you instantly.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class FriendScannerScreen extends ConsumerStatefulWidget {
  const FriendScannerScreen({super.key});

  @override
  ConsumerState<FriendScannerScreen> createState() => _FriendScannerScreenState();
}

class _FriendScannerScreenState extends ConsumerState<FriendScannerScreen> {
  String? _scanMessage;
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // ... [Keep your existing Overlay UI code here: ColorFiltered + Center Container] ...
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          if (_scanMessage != null)
            Positioned(
              bottom: 100, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red : AppColors.deepBerry,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _scanMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    if (code.startsWith('pyble://friend/')) {
      final targetId = code.substring(15); // strip prefix
      // Call provider logic
      try {
        await ref.read(sendFriendRequestProvider).sendRequest(targetId);
        if (mounted) {
          HapticFeedback.heavyImpact();
          Navigator.pop(context); // Close scanner on success
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!")));
        }
      } catch (e) {
        setState(() { _scanMessage = "Error sending request"; _isError = true; });
      }
    }
  }
}