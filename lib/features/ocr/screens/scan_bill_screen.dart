import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For tabular figures & haptics
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';
import '../../table/providers/table_provider.dart';
import '../../table/models/bill_item.dart';

class ScanBillScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ScanBillScreen({super.key, required this.tableId});

  @override
  ConsumerState<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends ConsumerState<ScanBillScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isScanning = false;

  // Form Controllers
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentTableProvider.notifier).loadTable(widget.tableId);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _isScanning = true;
        });

        await _scanBill(bytes, image.mimeType ?? 'image/jpeg');
      }
    } catch (e) {
      _showErrorSnackBar("Camera error: $e");
    }
  }

  Future<void> _scanBill(Uint8List bytes, String mimeType) async {
    try {
      final repository = ref.read(tableRepositoryProvider);
      final count = await repository.scanBill(
        tableId: widget.tableId,
        imageBytes: bytes,
        mimeType: mimeType,
      );

      await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);

      if (mounted) {
        HapticFeedback.mediumImpact();
        _showSuccessSnackBar('✨ Magic! Found $count items.');
      }
    } catch (e) {
      if (mounted) {
        _showManualEntryOptions();
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _addManualItem() async {
    final description = _descriptionController.text.trim();
    final price = double.parse(_priceController.text);

    try {
      await ref.read(currentTableProvider.notifier).addItem(
        description: description,
        price: price,
      );
      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pop(context); // Close dialog
        _descriptionController.clear();
        _priceController.clear();
      }
    } catch (e) {
      _showErrorSnackBar("Error adding item: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: theme.colorScheme.error),
    );
  }

  void _showSuccessSnackBar(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use Bright Green in dark mode for better contrast
    final color = isDark ? AppColors.brightGreen : AppColors.lushGreen;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final items = tableDataAsync.valueOrNull?.items ?? [];
    final hasItems = items.isNotEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      // FIX: Adapt background to Dark Plum/Light Crust
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Digitize Bill',
            style: TextStyle(
                color: theme.colorScheme.onSurface, // Dark Fig / White
                fontWeight: FontWeight.bold
            )
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (hasItems)
            TextButton(
              onPressed: () => context.go('/table/${widget.tableId}/invite'),
              child: const Text("Next",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: tableDataAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (_) {
          if (_isScanning) {
            return _buildScanningState();
          }

          if (items.isEmpty) {
            return _buildCameraView();
          }

          return _buildReceiptView(items);
        },
      ),
    );
  }

  // === VIEW 1: THE LENS (Empty State) ===
  Widget _buildCameraView() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Illustration
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              // FIX: Use Surface color (White/Ink)
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5
                ),
              ],
            ),
            child: Icon(Icons.receipt_long,
                size: 64,
                color: theme.colorScheme.primary.withOpacity(0.8)),
          ),
          const SizedBox(height: 32),

          Text(
            "Snap the Bill",
            style: theme.textTheme.headlineLarge?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "AI will magically extract items and prices.\nMake sure the receipt is well-lit.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: onSurface.withOpacity(0.6),
                height: 1.5
            ),
          ),

          const Spacer(),

          // Hero Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _captureImage(ImageSource.camera),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 4,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.allMd),
              ),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scan with Camera",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),

          // Secondary Options
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _captureImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.keyboard),
                  label: const Text("Manual"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // === VIEW 2: SCANNING (Animation) ===
  Widget _buildScanningState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
                strokeWidth: 6, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text(
            "Reading Receipt...",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            "Our AI elves are typing really fast",
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  // === VIEW 3: THE RECEIPT (Results) ===
  Widget _buildReceiptView(List<BillItem> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = items.fold<double>(0, (sum, item) => sum + item.price);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                // The "Paper" Receipt Card
                Container(
                  decoration: BoxDecoration(
                    // FIX: Use Surface Color (Snow vs Ink)
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    // In dark mode, use a subtle border instead of shadow for visibility
                    border: isDark ? Border.all(color: theme.dividerColor) : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 4)
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Receipt Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.storefront,
                                color: theme.colorScheme.onSurface, size: 32),
                            const SizedBox(height: 8),
                            Text("BILL DETAILS",
                                style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                          ],
                        ),
                      ),

                      // Items List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.description,
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.3),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                "${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Footer / Total
                      const SizedBox(height: 24),
                      const Divider(height: 1, indent: 24, endIndent: 24),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface)),
                            Text(
                              "${AppConstants.currencySymbol}${total.toStringAsFixed(2)}",
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                  fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),
                      ),

                      // Jagged Edge Visual (Matches surface color)
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // "Add More" Button
                TextButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Missing Item"),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ),

        // Bottom Sticky Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5)
              )
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/table/${widget.tableId}/invite'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.allMd),
                ),
                child: const Text("Looks Good, Invite Friends",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // === MANUAL ENTRY DIALOGS ===

  void _showManualEntryOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            const Text("Scan didn't work?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                "The lighting might be tricky. You can type items manually.",
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAddItemDialog();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text("Add Items Manually"),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Try Scanning Again"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Item"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: "Item Name", hintText: "e.g. Coffee"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: "Price", prefixText: "\$ "),
                validator: (val) =>
                double.tryParse(val!) == null ? "Invalid price" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) _addManualItem();
              },
              child: const Text("Add")),
        ],
      ),
    );
  }
}