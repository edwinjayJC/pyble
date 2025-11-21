import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pyble/features/auth/providers/user_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/supabase_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final profile = userProfileAsync.valueOrNull;
    final theme = Theme.of(context);

    // Calculate Initials Logic
    String initials = '?';
    if (profile != null && profile.displayName.isNotEmpty) {
      final parts = profile.displayName.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        initials = profile.displayName[0].toUpperCase();
      }
    }

    return Drawer(
      // FIX: Use theme background (Light Crust vs Dark Plum)
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. THE BRANDED HEADER
          _buildHeader(context, profile, initials),

          const SizedBox(height: AppSpacing.md),

          // 2. NAVIGATION ITEMS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.account_balance,
                  label: "Payment Methods",
                  onTap: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.paymentMethod);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: "Settings",
                  onTap: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.settings);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long_rounded,
                  label: "History",
                  onTap: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.history);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.school_outlined,
                  label: "Tutorial",
                  onTap: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.onboarding);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.description_outlined,
                  label: "Terms & Conditions",
                  onTap: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.terms);
                  },
                ),
              ],
            ),
          ),

          // 3. FOOTER (Sign Out & Version)
          Divider(color: theme.dividerColor), // FIX: Adaptive Divider

          _buildDrawerItem(
            context,
            icon: Icons.logout_rounded,
            label: "Sign Out",
            // Use Error color for semantic consistency
            color: theme.colorScheme.error,
            onTap: () => _handleSignOut(context, ref),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Version 1.0.0",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor, // FIX: Adaptive disabled text
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // === SUB-WIDGETS ===

  Widget _buildHeader(BuildContext context, dynamic profile, String initials) {
    // We keep the Header fixed to Deep Berry (Brand) because it looks good
    // in both modes and ensures white text legibility.
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.deepBerry,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepBerry, Color(0xFFD9275D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar Container
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 32,
              // Avatar background matches AppColors.snow (White) inside the DeepBerry header
              backgroundColor: AppColors.snow,
              backgroundImage: (profile?.avatarUrl != null)
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: (profile?.avatarUrl == null)
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBerry,
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          // User Info (Always White on Deep Berry)
          Text(
            profile?.displayName ?? 'Guest User',
            style: const TextStyle(
              color: AppColors.snow,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            profile?.email ?? 'No email',
            style: TextStyle(
              color: AppColors.snow.withOpacity(0.8),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    // FIX: Default color adapts to OnSurface (Dark Fig or White)
    final effectiveColor = color ?? theme.colorScheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: effectiveColor, size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      splashColor: effectiveColor.withOpacity(0.1),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            // FIX: Adaptive Text Color
            child: Text(
              "Cancel",
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            // FIX: Use Error color for destructive action
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final client = ref.read(supabaseClientProvider);
      final currentUserId = client.auth.currentUser?.id;
      await client.auth.signOut();
      ref.invalidate(userProfileProvider);
      final prefs = await SharedPreferences.getInstance();
      if (currentUserId != null) {
        await prefs.remove('${AppConstants.tutorialSeenKey}_$currentUserId');
      } else {
        await prefs.remove(AppConstants.tutorialSeenKey);
      }

      if (context.mounted) {
        context.go(RoutePaths.auth);
      }
    }
  }
}
