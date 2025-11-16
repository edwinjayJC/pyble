import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/route_names.dart';
import '../providers/table_provider.dart';
import '../models/bill_item.dart';

class AddItemsScreen extends ConsumerStatefulWidget {
  final String tableId;

  const AddItemsScreen({super.key, required this.tableId});

  @override
  ConsumerState<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends ConsumerState<AddItemsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isLoading = false;
  bool _splitEvenlyMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load existing items
    ref.read(tableItemsProvider.notifier).loadItems(widget.tableId);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(tableItemsProvider.notifier).addItem(
            tableId: widget.tableId,
            description: _descriptionController.text.trim(),
            price: double.parse(_priceController.text),
          );

      // Clear form
      _descriptionController.clear();
      _priceController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add item. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addTotalForEvenSplit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(tableItemsProvider.notifier).addItem(
            tableId: widget.tableId,
            description: 'Total Bill (Even Split)',
            price: double.parse(_priceController.text),
          );

      // Navigate to invite screen
      if (mounted) {
        context.pushReplacementNamed(
          RouteNames.hostInvite,
          pathParameters: {'tableId': widget.tableId},
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add total. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _splitEvenlyMode = !_splitEvenlyMode;
      _descriptionController.clear();
      _priceController.clear();
    });
  }

  void _finishAddingItems() {
    final items = ref.read(tableItemsProvider).value ?? [];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: AppColors.warmSpice,
        ),
      );
      return;
    }

    context.pushReplacementNamed(
      RouteNames.hostInvite,
      pathParameters: {'tableId': widget.tableId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(tableItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_splitEvenlyMode ? 'Enter Total' : 'Add Items'),
        actions: [
          if (!_splitEvenlyMode)
            TextButton(
              onPressed: _finishAddingItems,
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode toggle
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _splitEvenlyMode ? _toggleMode : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_splitEvenlyMode
                            ? AppColors.lightBerry
                            : null,
                      ),
                      child: const Text('Add Items'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: !_splitEvenlyMode ? _toggleMode : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _splitEvenlyMode
                            ? AppColors.lightBerry
                            : null,
                      ),
                      child: const Text('Split Evenly'),
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                color: AppColors.lightWarmSpice,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.warmSpice),
                  textAlign: TextAlign.center,
                ),
              ),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_splitEvenlyMode) ...[
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Item Description',
                          hintText: 'e.g., Caesar Salad',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (!_splitEvenlyMode &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: _splitEvenlyMode ? 'Total Amount' : 'Price',
                        hintText: '0.00',
                        prefixText: 'R ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_splitEvenlyMode
                                ? _addTotalForEvenSplit
                                : _addItem),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.snow,
                                ),
                              )
                            : Text(_splitEvenlyMode
                                ? 'Continue'
                                : 'Add Item'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Items list (only in add items mode)
            if (!_splitEvenlyMode) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      'Added Items',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    itemsAsync.when(
                      data: (items) => Text(
                        'Total: R ${_calculateTotal(items).toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: itemsAsync.when(
                  data: (items) => items.isEmpty
                      ? const Center(
                          child: Text(
                            'No items added yet',
                            style: TextStyle(color: AppColors.disabledText),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              title: Text(item.description),
                              trailing: Text(
                                'R ${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, __) => Center(
                    child: Text('Error: $e'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateTotal(List<BillItem> items) {
    return items.fold(0, (sum, item) => sum + item.price);
  }
}
