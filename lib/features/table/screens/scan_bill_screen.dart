import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/route_names.dart';
import '../providers/table_provider.dart';

class ScanBillScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ScanBillScreen({super.key, required this.tableId});

  @override
  ConsumerState<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends ConsumerState<ScanBillScreen> {
  MobileScannerController? _cameraController;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // In a real implementation, we would capture the image and send to OCR API
      // For now, we'll simulate a delay and show the fallback options
      await Future.delayed(const Duration(seconds: 2));

      // Simulate OCR failure to show escape hatch
      throw Exception('OCR not implemented yet');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to scan bill. Please try again or add items manually.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showEscapeHatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Failed'),
        content: const Text(
          'We couldn\'t read your bill. How would you like to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _captureAndProcess();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pushReplacementNamed(
                RouteNames.addItems,
                pathParameters: {'tableId': widget.tableId},
              );
            },
            child: const Text('Add Manually'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Bill'),
        actions: [
          TextButton(
            onPressed: () {
              context.pushReplacementNamed(
                RouteNames.addItems,
                pathParameters: {'tableId': widget.tableId},
              );
            },
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview
            Expanded(
              child: Stack(
                children: [
                  if (_cameraController != null)
                    MobileScanner(
                      controller: _cameraController!,
                      onDetect: (capture) {
                        // We're using this for general image capture, not barcode scanning
                      },
                    ),

                  // Overlay instructions
                  Positioned(
                    top: AppSpacing.lg,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.darkFig.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Position your bill within the frame and tap the capture button',
                        style: TextStyle(color: AppColors.snow),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Processing overlay
                  if (_isProcessing)
                    Container(
                      color: AppColors.darkFig.withOpacity(0.7),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.snow,
                            ),
                            SizedBox(height: AppSpacing.md),
                            Text(
                              'Processing bill...',
                              style: TextStyle(color: AppColors.snow),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.lightWarmSpice,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.warmSpice),
                  textAlign: TextAlign.center,
                ),
              ),

            // Controls
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Capture button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _captureAndProcess,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Bill'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Manual entry option
                  TextButton(
                    onPressed: () {
                      context.pushReplacementNamed(
                        RouteNames.addItems,
                        pathParameters: {'tableId': widget.tableId},
                      );
                    },
                    child: const Text('Add Items Manually'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
