import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pyble'),
      ),
      drawer: _buildDrawer(context, ref, profileAsync),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome message
              profileAsync.when(
                data: (profile) => Text(
                  'Welcome${profile != null ? ', ${profile.displayName}' : ''}!',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xl * 2),

              // Create Table button
              ElevatedButton.icon(
                onPressed: () {
                  context.pushNamed(RouteNames.createTable);
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Table'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Join Table button
              OutlinedButton.icon(
                onPressed: () {
                  context.pushNamed(RouteNames.joinTable);
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Join Table'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> profileAsync,
  ) {
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + AppSpacing.lg,
              bottom: AppSpacing.lg,
              left: AppSpacing.md,
              right: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.deepBerry,
            ),
            child: profileAsync.when(
              data: (profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.snow,
                    child: Text(
                      profile?.displayName.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBerry,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    profile?.displayName ?? 'User',
                    style: const TextStyle(
                      color: AppColors.snow,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profile?.email ?? '',
                    style: TextStyle(
                      color: AppColors.snow.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.snow),
              ),
              error: (_, __) => const Text(
                'Error loading profile',
                style: TextStyle(color: AppColors.snow),
              ),
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('Payment Methods'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to payment methods
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  onTap: () {
                    Navigator.pop(context);
                    context.pushNamed(RouteNames.history);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    context.pushNamed(RouteNames.settings);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.warmSpice,
                  ),
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(color: AppColors.warmSpice),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteAccountDialog(context, ref);
                  },
                ),
              ],
            ),
          ),

          // Sign out button at bottom
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: AppColors.warmSpice,
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.warmSpice),
            ),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(supabaseClientProvider).auth.signOut();
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(userProfileProvider.notifier).deleteAccount();
                await ref.read(supabaseClientProvider).auth.signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: AppColors.warmSpice,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.warmSpice),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
