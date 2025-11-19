import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';

// Feature Imports
import '../providers/table_provider.dart';
import '../../table/models/participant.dart';

class HostInviteScreen extends ConsumerStatefulWidget {
  final String tableId;

  const HostInviteScreen({super.key, required this.tableId});

  @override
  ConsumerState<HostInviteScreen> createState() => _HostInviteScreenState();
}

class _HostInviteScreenState extends ConsumerState<HostInviteScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final theme = Theme.of(context);

    return Scaffold(
      // FIX: Adapt background (Light Crust vs Dark Plum)
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Invite Friends',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: tableDataAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tableData) {
          if (tableData == null) return const Center(child: Text("Table not found"));

          final tableCode = tableData.table.code;
          final joinLink = '${AppConstants.appScheme}://${AppConstants.joinPath}?code=$tableCode';
          final participants = tableData.participants;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.md),

                        // 1. The "Hero" QR Card
                        _buildQRCard(context, joinLink),

                        const SizedBox(height: AppSpacing.xl),

                        // 2. The Code & Share Actions
                        _buildCodeSection(context, tableCode, joinLink),

                        const SizedBox(height: AppSpacing.xl),

                        // 3. The "Live Lobby"
                        _buildLobbySection(context, participants),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),

                // 4. Sticky "Let's Go" Button
                _buildStickyFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // === Sub-Widgets ===

  Widget _buildQRCard(BuildContext context, String joinLink) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // FIX: Surface color
        color: theme.colorScheme.surface,
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
          // QR Code Wrapper
          // We purposely keep the QR background WHITE even in dark mode
          // to ensure the Deep Berry / Dark Fig contrast works for cameras.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: joinLink,
              version: QrVersions.auto,
              size: 200.0,
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
            "Scan to Join",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSection(BuildContext context, String code, String link) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Monospace Code Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            // FIX: Surface Color
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontFamily: 'Courier', // FORCE MONOSPACE
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              // FIX: Text Color
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Code copied!'),
                    backgroundColor: theme.colorScheme.primary,
                    duration: const Duration(milliseconds: 1000),
                  ),
                );
              },
              icon: Icon(Icons.copy, size: 18, color: theme.colorScheme.primary),
              label: Text("Copy Code", style: TextStyle(color: theme.colorScheme.primary)),
            ),
            Container(height: 20, width: 1, color: theme.dividerColor),
            TextButton.icon(
              onPressed: () {
                Share.share('Join my Pyble table! Code: $code\nLink: $link');
              },
              icon: Icon(Icons.share, size: 18, color: theme.colorScheme.primary),
              label: Text("Share Link", style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLobbySection(BuildContext context, List<Participant> participants) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              "IN THE LOBBY (${participants.length})",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (participants.isEmpty)
        // Empty State
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.disabledColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Waiting for friends...",
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          )
        else
        // The Avatar Cluster (Wrap)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: participants.map((p) => _buildLobbyAvatar(context, p)).toList(),
          ),
      ],
    );
  }

  Widget _buildLobbyAvatar(BuildContext context, Participant p) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lushGreen, width: 2), // Green ring = Joined
          ),
          child: CircleAvatar(
            radius: 24,
            // FIX: Use Theme for avatar bg
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
            child: p.avatarUrl == null
                ? Text(p.initials, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          p.displayName.split(' ').first, // First name only for layout
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildStickyFooter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // FIX: Footer background
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5)
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // Navigate to scan bill screen
            context.go('/table/${widget.tableId}/scan');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          ),
          child: const Text(
            "Next - Scan Bill",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}