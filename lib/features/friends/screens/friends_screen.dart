import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
  bool _showScanner = false;
  bool _showQRCode = false;
  String? _scanMessage;
  bool _scanIsError = false;

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
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final userId = profile?.id ?? '';
    final friendLink = 'pyble://friend/$userId';

    if (_showScanner) {
      return _buildScannerScreen(context);
    }

    if (_showQRCode) {
      return _buildQRCodeScreen(context, friendLink, profile?.displayName ?? 'User');
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
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
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code, color: colorScheme.onSurface),
            tooltip: 'Show my QR code',
            onPressed: () {
              setState(() {
                _showQRCode = true;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: colorScheme.onSurface),
            tooltip: 'Scan to add a friend',
            onPressed: () {
              setState(() {
                _showScanner = true;
                _scanMessage = null;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
          ],
        ),
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

  Widget _buildFriendsListTab(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(
        context,
        error,
        onRetry: () => ref.invalidate(friendsListProvider),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return _buildEmptyFriendsState(context);
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(friendsListProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return _buildFriendTile(context, friend);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendTile(BuildContext context, Friend friend) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          backgroundImage: friend.avatarUrl != null
              ? NetworkImage(friend.avatarUrl!)
              : null,
          child: friend.avatarUrl == null
              ? Text(
                  friend.initials,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          friend.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: friend.isAuto
            ? Text(
                'Auto-added friend',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.person_remove, color: colorScheme.error),
          tooltip: 'Remove friend',
          onPressed: () => _confirmRemoveFriend(context, friend),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveFriend(BuildContext context, Friend friend) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${friend.displayName} from your friends list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(friendsListProvider.notifier).removeFriend(friend.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${friend.displayName} removed from friends'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove friend: ${_getErrorMessage(e)}'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildRequestsTab(BuildContext context) {
    final requestsAsync = ref.watch(friendRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(
        context,
        error,
        onRetry: () => ref.invalidate(friendRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return _buildEmptyRequestsState(context);
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(friendRequestsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestTile(context, request);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestTile(BuildContext context, FriendRequest request) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  backgroundImage: request.fromAvatarUrl != null
                      ? NetworkImage(request.fromAvatarUrl!)
                      : null,
                  child: request.fromAvatarUrl == null
                      ? Text(
                          request.initials,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.fromDisplayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Sent ${_formatDate(request.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _rejectRequest(context, request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => _acceptRequest(context, request),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(BuildContext context, FriendRequest request) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await ref.read(friendRequestsProvider.notifier).acceptRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.fromDisplayName} added to friends!'),
            backgroundColor: AppColors.lushGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: ${_getErrorMessage(e)}'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(BuildContext context, FriendRequest request) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await ref.read(friendRequestsProvider.notifier).rejectRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline request: ${_getErrorMessage(e)}'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildEmptyFriendsState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No friends yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scan a friend\'s QR code or share yours to connect!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _showScanner = true;
                });
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRequestsState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No pending requests',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Friend requests you receive will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    Object error, {
    required VoidCallback onRetry,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _getErrorMessage(error),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeScreen(BuildContext context, String friendLink, String username) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () {
            setState(() {
              _showQRCode = false;
            });
          },
        ),
        title: Text(
          'My Friend Code',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: friendLink,
                          version: QrVersions.auto,
                          size: 220.0,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: AppColors.deepBerry,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: AppColors.darkFig,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Show this to add you as a friend",
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Tip: Friends can scan this QR to add you. They\'ll instantly be able to join your tables without approval.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _showScanner = false;
              _scanMessage = null;
            });
          },
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onQRCodeDetected,
          ),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: 1,
                      color: AppColors.lushGreen.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Scan a friend's QR code",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                if (_scanMessage != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _scanMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _scanIsError ? Colors.redAccent : Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) async {
    for (final barcode in capture.barcodes) {
      final String? code = barcode.rawValue;
      if (code == null) continue;

      // Check if it's a friend QR code
      if (code.startsWith('pyble://friend/')) {
        final targetUserId = code.substring('pyble://friend/'.length);

        if (targetUserId.isEmpty) {
          setState(() {
            _scanMessage = "Invalid friend code.";
            _scanIsError = true;
          });
          HapticFeedback.vibrate();
          continue;
        }

        // Send friend request
        setState(() {
          _scanMessage = "Sending friend request...";
          _scanIsError = false;
        });

        try {
          final sendService = ref.read(sendFriendRequestProvider);
          await sendService.sendRequest(targetUserId);

          setState(() {
            _showScanner = false;
            _scanMessage = null;
          });

          if (!mounted) return;
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Friend request sent!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        } catch (e) {
          setState(() {
            _scanMessage = _getErrorMessage(e);
            _scanIsError = true;
          });
          HapticFeedback.vibrate();
        }
        break;
      }

      // Check for old-style friend code format
      if (code.startsWith('Friend:')) {
        setState(() {
          _scanMessage = "This is an old friend code format. Please ask your friend to update their app.";
          _scanIsError = true;
        });
        HapticFeedback.vibrate();
        continue;
      }

      // Not a friend code
      setState(() {
        _scanMessage = "That doesn't look like a friend code. Use Join Table for table codes.";
        _scanIsError = true;
      });
      HapticFeedback.vibrate();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return 'Already friends or request pending';
      }
      if (error.statusCode == 404) {
        return 'User not found';
      }
      if (error.statusCode == 400) {
        return error.message;
      }
      return error.message;
    }
    return 'An unexpected error occurred';
  }
}
