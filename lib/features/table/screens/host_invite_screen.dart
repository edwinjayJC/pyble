import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/table_provider.dart';

class HostInviteScreen extends ConsumerWidget {
  final String tableId;

  const HostInviteScreen({super.key, required this.tableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableData = ref.watch(currentTableProvider).valueOrNull;

    if (tableData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invite Participants')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tableCode = tableData.table.code;
    final joinLink =
        '${AppConstants.appScheme}://${AppConstants.joinPath}?code=$tableCode';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Participants'),
        actions: [
          TextButton(
            onPressed: () {
              // Navigate to claiming screen (Phase 2)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Claiming screen coming in Phase 2'),
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Share with your table',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Participants can scan the QR code or enter the code to join',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // QR Code
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.snow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkFig.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: joinLink,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: AppColors.snow,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.deepBerry,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.darkFig,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Table Code
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightCrust,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Table Code',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      tableCode,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            letterSpacing: 8,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tableCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard'),
                            backgroundColor: AppColors.lushGreen,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Code'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Share Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      'Join my Pyble table!\n\n'
                      'Code: $tableCode\n'
                      'Link: $joinLink\n\n'
                      'Download Pyble to split bills easily!',
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Invite Link'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Participants Status
              if (tableData.participants.isNotEmpty) ...[
                const Divider(height: AppSpacing.xl),
                Text(
                  'Participants Joined',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                ...tableData.participants.map((participant) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.deepBerry,
                        child: Text(
                          participant.initials,
                          style: const TextStyle(color: AppColors.snow),
                        ),
                      ),
                      title: Text(participant.displayName),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: AppColors.lushGreen,
                      ),
                    )),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.lightCrust,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 48,
                        color: AppColors.disabledText,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Waiting for participants to join...',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.disabledText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
