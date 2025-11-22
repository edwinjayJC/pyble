import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

// Feature Imports
import '../../auth/providers/user_profile_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  bool _showScanner = false;
  String? _scanMessage;
  bool _scanIsError = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final username = (profile != null && profile.displayName.trim().isNotEmpty)
        ? profile.displayName
        : (profile?.email ?? 'guest');
    final friendCode = _generateFriendCode(username);
    final friendLink = 'Friend:$friendCode';

    return Scaffold(
      backgroundColor: _showScanner ? Colors.black : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _showScanner ? Colors.transparent : theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _showScanner ? Icons.close : Icons.arrow_back,
            color: _showScanner ? Colors.white : colorScheme.onSurface,
          ),
          onPressed: () {
            if (_showScanner) {
              setState(() {
                _showScanner = false;
                _scanMessage = null;
              });
            } else {
              context.pop();
            }
          },
        ),
        title: !_showScanner
            ? Text(
                'Friends',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.qr_code_scanner,
              color: _showScanner ? Colors.white : colorScheme.onSurface,
            ),
            tooltip: 'Scan to add a friend',
            onPressed: () {
              setState(() {
                _showScanner = true;
                _scanMessage = null;
              });
            },
          ),
        ],
        systemOverlayStyle:
            _showScanner ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      extendBodyBehindAppBar: _showScanner,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _showScanner
            ? _buildScannerView(context)
            : _buildFriendCodeView(context, friendLink, friendCode, username),
      ),
    );
  }

  Widget _buildFriendCodeView(
      BuildContext context, String friendLink, String friendCode, String username) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return SafeArea(
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
              'Tip: Share this QR with friends. They can scan it using the scanner in the top right.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView(BuildContext context) {
    return Stack(
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
                Text(
                  _scanMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _scanIsError ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showScanner = false;
                  _scanMessage = null;
                });
              },
              style: TextButton.styleFrom(backgroundColor: Colors.white24),
              child: const Text(
                "Back",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final String? code = barcode.rawValue;
      if (code == null) continue;

      if (!code.startsWith('Friend:')) {
        setState(() {
          _scanMessage = "That looks like a table code. Use Join Table instead.";
          _scanIsError = true;
        });
        HapticFeedback.vibrate();
        continue;
      }

      final friendId = code.substring('Friend:'.length);

      setState(() {
        _showScanner = false;
        _scanMessage = null;
      });

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend added: $friendId'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      break;
    }
  }

  String _generateFriendCode(String username) {
    final normalized = username.trim().toLowerCase();
    int hash = 0;
    for (final codeUnit in normalized.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    final code = hash.abs() % 10000000000;
    return code.toString().padLeft(10, '0');
  }
}
