import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/table_provider.dart';
import '../repository/table_repository.dart';

class JoinTableScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinTableScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinTableScreen> createState() => _JoinTableScreenState();
}

class _JoinTableScreenState extends ConsumerState<JoinTableScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _showScanner = false; // Mode Toggle
  bool _requestPending = false; // Join request pending approval
  String? _errorMessage;
  String? _pendingCode; // Code for polling
  Timer? _pollingTimer;

  // Animation for error shake or transitions could go here
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Auto-join logic
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _codeController.text = widget.initialCode!;
        _joinTable(widget.initialCode!);
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _codeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _joinTable(String code) async {
    if (code.isEmpty || code.length != 6) return;

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _requestPending = false;
    });

    try {
      final result = await ref
          .read(currentTableProvider.notifier)
          .joinTableByCode(code.toUpperCase());

      if (mounted) {
        if (result.isSuccess && result.table != null) {
          // Friend - auto-joined
          HapticFeedback.heavyImpact(); // Success thud
          context.go('/table/${result.table!.id}/claim');
        } else if (result.isPending) {
          // Non-friend - request pending
          HapticFeedback.mediumImpact();
          setState(() {
            _requestPending = true;
            _pendingCode = code.toUpperCase();
            _isLoading = false;
          });
          // Start polling for acceptance
          _startPolling();
        }
      }
    } catch (e) {
      HapticFeedback.vibrate(); // Error buzz
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted && !_requestPending) setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollForAcceptance(),
    );
  }

  Future<void> _pollForAcceptance() async {
    if (_pendingCode == null || !mounted) return;

    try {
      final result = await ref
          .read(currentTableProvider.notifier)
          .joinTableByCode(_pendingCode!);

      if (result.isSuccess && result.table != null) {
        // Request was accepted!
        _pollingTimer?.cancel();
        if (mounted) {
          HapticFeedback.heavyImpact();
          context.go('/table/${result.table!.id}/claim');
        }
      }
      // If still pending, continue polling
    } catch (e) {
      // Check if rejected (blocked or other error)
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('blocked') || errorMsg.contains('rejected')) {
        _pollingTimer?.cancel();
        if (mounted) {
          HapticFeedback.vibrate();
          setState(() {
            _requestPending = false;
            _errorMessage = 'Your request was declined';
          });
        }
      }
      // Other errors - continue polling
    }
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        HapticFeedback.lightImpact(); // Feedback on scan

        // Extract code logic
        String tableCode = code;
        if (code.contains('code=')) {
          final uri = Uri.tryParse(code);
          if (uri != null) {
            tableCode = uri.queryParameters['code'] ?? code;
          }
        }

        // Validate length before switching
        if (tableCode.length >= 6) {
          setState(() {
            _showScanner = false;
            _codeController.text = tableCode.substring(0, 6); // Safety clip
          });
          _joinTable(tableCode);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // FIX: Use Theme background, or Black if scanner is active
      backgroundColor: _showScanner
          ? Colors.black
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _showScanner
            ? Colors.transparent
            : theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: _showScanner ? Colors.white : theme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (_showScanner) {
              setState(() => _showScanner = false);
            } else {
              context.pop();
            }
          },
        ),
        title: !_showScanner
            ? Text(
                "Enter Code",
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        systemOverlayStyle: _showScanner
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      extendBodyBehindAppBar: _showScanner,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _requestPending
            ? _buildPendingRequestView()
            : _showScanner
                ? _buildScannerView()
                : _buildManualEntryView(),
      ),
    );
  }

  // === VIEW: PENDING REQUEST (Waiting for Host Approval) ===
  Widget _buildPendingRequestView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Request Sent!",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Waiting for host approval...",
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "The host will review your request to join the table. You'll be notified when they respond.",
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                "Go Back",
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === VIEW 1: THE MANUAL ENTRY ===
  Widget _buildManualEntryView() {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.vpn_key_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              "What's the magic word?",
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Ask the host for the 6-character code.",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 40),

            // Hero Input Field
            SizedBox(
              width: 280,
              child: TextField(
                controller: _codeController,
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  // FIX: Use Primary Brand Color for text
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontFamily: 'Courier', // Monospace for alignment
                ),
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.text, // Alphanumeric
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                decoration: InputDecoration(
                  counterText: "", // Hide character count
                  filled: true,
                  // FIX: Use Surface color (Ink/Snow)
                  fillColor: theme.colorScheme.surface,
                  hintText: "______",
                  hintStyle: TextStyle(
                    color: theme.dividerColor,
                    letterSpacing: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val.length == 6) {
                    _joinTable(val);
                  }
                },
              ),
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Loading or Buttons
            if (_isLoading)
              CircularProgressIndicator(color: theme.colorScheme.primary)
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _joinTable(_codeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Enter Table",
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => setState(() => _showScanner = true),
                    icon: Icon(
                      Icons.qr_code_scanner,
                      color: theme.colorScheme.onSurface,
                    ),
                    label: Text(
                      "Scan QR Code instead",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // === VIEW 2: THE SCANNER (With Overlay) ===
  Widget _buildScannerView() {
    return Stack(
      children: [
        // 1. The Camera Feed
        MobileScanner(onDetect: _onQRCodeDetected),

        // 2. The Dark Overlay with Cutout
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
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Visual Guide (Corners)
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Stack(
              children: [
                // Scan Line Animation (Static for MVP)
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

        // 4. Hint Text
        const Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Text(
            "Point at the Host's QR Code",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),

        // 5. Manual Entry Fallback
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton(
              onPressed: () => setState(() => _showScanner = false),
              style: TextButton.styleFrom(backgroundColor: Colors.white24),
              child: const Text(
                "Type Code Manually",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
