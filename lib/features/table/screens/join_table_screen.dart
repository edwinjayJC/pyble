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

class JoinTableScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinTableScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinTableScreen> createState() => _JoinTableScreenState();
}

class _JoinTableScreenState extends ConsumerState<JoinTableScreen> with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _showScanner = false; // Mode Toggle
  String? _errorMessage;

  // Animation for error shake or transitions could go here
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

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
    });

    try {
      await ref.read(currentTableProvider.notifier).joinTableByCode(code.toUpperCase());

      if (mounted) {
        HapticFeedback.heavyImpact(); // Success thud
        final tableData = ref.read(currentTableProvider).valueOrNull;
        if (tableData != null) {
          context.go('/table/${tableData.table.id}/claim');
        }
      }
    } catch (e) {
      HapticFeedback.vibrate(); // Error buzz
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Scaffold(
      backgroundColor: _showScanner ? Colors.black : AppColors.lightCrust,
      appBar: AppBar(
        backgroundColor: _showScanner ? Colors.transparent : AppColors.lightCrust,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _showScanner ? Colors.white : AppColors.darkFig),
          onPressed: () {
            if (_showScanner) {
              setState(() => _showScanner = false);
            } else {
              context.pop();
            }
          },
        ),
        title: !_showScanner ? const Text(
            "Enter Code",
            style: TextStyle(color: AppColors.darkFig, fontWeight: FontWeight.bold)
        ) : null,
        systemOverlayStyle: _showScanner ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      extendBodyBehindAppBar: _showScanner,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _showScanner ? _buildScannerView() : _buildManualEntryView(),
      ),
    );
  }

  // === VIEW 1: THE MANUAL ENTRY ===
  Widget _buildManualEntryView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vpn_key_outlined, size: 48, color: AppColors.deepBerry),
            const SizedBox(height: 24),
            Text(
              "What's the magic word?",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.darkFig,
                  fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Ask the host for the 6-character code.",
              style: TextStyle(color: AppColors.darkFig.withOpacity(0.6)),
            ),

            const SizedBox(height: 40),

            // Hero Input Field
            SizedBox(
              width: 280,
              child: TextField(
                controller: _codeController,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: AppColors.deepBerry,
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
                  fillColor: AppColors.snow,
                  hintText: "______",
                  hintStyle: TextStyle(color: AppColors.paleGray, letterSpacing: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.paleGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.paleGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.deepBerry, width: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warmSpice.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, size: 18, color: AppColors.warmSpice),
                    const SizedBox(width: 8),
                    Text(_errorMessage!, style: TextStyle(color: AppColors.warmSpice, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Loading or Buttons
            if (_isLoading)
              const CircularProgressIndicator(color: AppColors.deepBerry)
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _joinTable(_codeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepBerry,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Enter Table", style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => setState(() => _showScanner = true),
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.darkFig),
                    label: const Text("Scan QR Code instead", style: TextStyle(color: AppColors.darkFig, fontWeight: FontWeight.bold)),
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
        MobileScanner(
          onDetect: _onQRCodeDetected,
          // controller: MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
        ),

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
                // Scan Line Animation (Optional, static here for MVP)
                Center(child: Container(height: 1, color: AppColors.lushGreen.withOpacity(0.5))),
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
              child: const Text("Type Code Manually", style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}