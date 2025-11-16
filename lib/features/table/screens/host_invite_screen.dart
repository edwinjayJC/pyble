import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/table_provider.dart';

class HostInviteScreen extends ConsumerStatefulWidget {
  final String tableId;

  const HostInviteScreen({super.key, required this.tableId});

  @override
  ConsumerState<HostInviteScreen> createState() => _HostInviteScreenState();
}

class _HostInviteScreenState extends ConsumerState<HostInviteScreen> {
  @override
  void initState() {
    super.initState();
    // Load table data
    ref.read(currentTableProvider.notifier).loadTableById(widget.tableId);
  }

  String _getInviteLink(String code) {
    return '${AppConstants.deepLinkScheme}://join?code=$code';
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        backgroundColor: AppColors.lushGreen,
      ),
    );
  }

  void _shareInvite(String code) {
    final link = _getInviteLink(code);
    Share.share(
      'Join my table on Pyble! Use code: $code or click: $link',
      subject: 'Join my Pyble table',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableAsync = ref.watch(currentTableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Participants'),
      ),
      body: SafeArea(
        child: tableAsync.when(
          data: (table) {
            if (table == null) {
              return const Center(child: Text('Table not found'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions
                  Text(
                    'Share this code with your friends to let them join the table',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.disabledText,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // QR Code
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.paleGray.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _getInviteLink(table.code),
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: AppColors.snow,
                        eyeStyle: const QrEyeStyle(
                          color: AppColors.deepBerry,
                          eyeShape: QrEyeShape.square,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          color: AppColors.darkFig,
                          dataModuleShape: QrDataModuleShape.square,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Table Code
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.lightCrust,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Table Code',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              table.code,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    letterSpacing: 8,
                                    color: AppColors.deepBerry,
                                  ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            IconButton(
                              onPressed: () => _copyCode(table.code),
                              icon: const Icon(Icons.copy),
                              color: AppColors.deepBerry,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Share button
                  ElevatedButton.icon(
                    onPressed: () => _shareInvite(table.code),
                    icon: const Icon(Icons.share),
                    label: const Text('Share Invite Link'),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Waiting message
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.lightBerry,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.deepBerry.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.deepBerry,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Waiting for participants to join...',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.deepBerry,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, __) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.warmSpice,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Error: $e'),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(currentTableProvider.notifier)
                        .loadTableById(widget.tableId);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
