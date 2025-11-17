import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../providers/table_provider.dart';

class JoinTableScreen extends ConsumerStatefulWidget {
  const JoinTableScreen({super.key});

  @override
  ConsumerState<JoinTableScreen> createState() => _JoinTableScreenState();
}

class _JoinTableScreenState extends ConsumerState<JoinTableScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showScanner = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinTable(String code) async {
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(currentTableProvider.notifier).joinTableByCode(code.toUpperCase());
      if (mounted) {
        final tableData = ref.read(currentTableProvider).valueOrNull;
        if (tableData != null) {
          context.go('/table/${tableData.table.id}/claim');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        // Extract code from deep link or use directly
        String tableCode = code;
        if (code.contains('code=')) {
          final uri = Uri.tryParse(code);
          if (uri != null) {
            tableCode = uri.queryParameters['code'] ?? code;
          }
        }

        setState(() {
          _showScanner = false;
          _codeController.text = tableCode;
        });
        _joinTable(tableCode);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Table'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _showScanner ? _buildScanner() : _buildCodeEntry(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onQRCodeDetected,
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Scan the QR code shown on the host\'s device',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 16,
          right: 16,
          child: ElevatedButton(
            onPressed: () => setState(() => _showScanner = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.snow,
              foregroundColor: AppColors.deepBerry,
            ),
            child: const Text('Enter Code Manually'),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.group_add,
              size: 80,
              color: AppColors.deepBerry,
            ),
            const SizedBox(height: 24),
            Text(
              'Join a Table',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkFig,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character code or scan the QR code to join',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.darkFig.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Table Code',
                hintText: 'ABC123',
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the table code';
                }
                if (value.length != 6) {
                  return 'Code must be 6 characters';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightWarmSpice,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.warmSpice),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.warmSpice),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _joinTable(_codeController.text);
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Table'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => setState(() => _showScanner = true),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}
