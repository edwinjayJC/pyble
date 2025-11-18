import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pyble/core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
  String? _imageMimeType;
  bool _isScanning = false;
  bool _scanComplete = false;

  // Manual entry
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Load table data when screen opens
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

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageMimeType = image.mimeType ?? 'image/jpeg';
      });
      await _scanBill();
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageMimeType = image.mimeType ?? 'image/jpeg';
      });
      await _scanBill();
    }
  }

  Future<void> _scanBill() async {
    if (_imageBytes == null || _imageMimeType == null) return;

    setState(() => _isScanning = true);

    try {
      final repository = ref.read(tableRepositoryProvider);
      final itemCount = await repository.scanBill(
        tableId: widget.tableId,
        imageBytes: _imageBytes!,
        mimeType: _imageMimeType!,
      );

      setState(() {
        _scanComplete = true;
      });

      // Refresh table data to get the scanned items
      await ref.read(currentTableProvider.notifier).loadTable(widget.tableId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $itemCount items'),
            backgroundColor: AppColors.lushGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
        _showManualEntryOptions();
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _showManualEntryOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scan Failed',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Choose an alternative method:'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddItemDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Items Manually'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEnterTotalDialog();
                },
                icon: const Icon(Icons.calculate),
                label: const Text('Enter Total & Split Evenly'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Try Scanning Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    _descriptionController.clear();
    _priceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Item Description',
                  hintText: 'e.g., Burger',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addManualItem();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualItem() async {
    final description = _descriptionController.text;
    final price = double.parse(_priceController.text);

    try {
      await ref.read(currentTableProvider.notifier).addItem(
            description: description,
            price: price,
          );

      setState(() {
        _scanComplete = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added'),
            backgroundColor: AppColors.lushGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    }
  }

  void _showEnterTotalDialog() {
    _priceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Bill Total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will create a single item for the total amount that will be split evenly among all participants.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Total Amount',
                prefixText: '${AppConstants.currencySymbol} ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(_priceController.text);
              if (price != null && price > 0) {
                Navigator.pop(context);
                _descriptionController.text = 'Bill Total';
                _priceController.text = price.toString();
                await _addManualItem();
              }
            },
            child: const Text('Add Total'),
          ),
        ],
      ),
    );
  }

  void _proceedToInvite() {
    context.go('/table/${widget.tableId}/invite');
  }

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final tableData = tableDataAsync.valueOrNull;
    final items = tableData?.items ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Bill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _proceedToInvite,
              child: const Text('Next'),
            ),
        ],
      ),
      body: tableDataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.warmSpice),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(currentTableProvider.notifier).loadTable(widget.tableId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (_) => SafeArea(
        child: Column(
          children: [
            if (!_scanComplete && items.isEmpty) ...[
              Expanded(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.document_scanner,
                        size: 80,
                        color: AppColors.deepBerry,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Scan Your Bill',
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Take a photo of your restaurant bill to automatically extract items',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_isScanning) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        const Text('Scanning bill...'),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Choose from Gallery'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: _showAddItemDialog,
                          child: const Text('Add Items Manually'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Show items list
              Padding(
                padding: AppSpacing.screenPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bill Items',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      onPressed: _showAddItemDialog,
                      icon: const Icon(Icons.add_circle),
                      color: AppColors.deepBerry,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No items added yet'))
                    : ListView.separated(
                        padding: AppSpacing.screenPadding,
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(item.description),
                            trailing: Text(
                              '${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${items.fold<double>(0, (sum, item) => sum + item.price).toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppColors.deepBerry,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _proceedToInvite,
                          child: const Text('Continue to Invite'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
