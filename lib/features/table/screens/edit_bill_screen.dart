import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/app_constants.dart';

// Feature Imports
import '../providers/table_provider.dart';
import '../models/bill_item.dart';

class EditBillScreen extends ConsumerStatefulWidget {
  final String tableId;

  const EditBillScreen({super.key, required this.tableId});

  @override
  ConsumerState<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends ConsumerState<EditBillScreen> {
  // Controllers for the Bottom Sheet
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Silent reload to ensure data is fresh
      ref
          .read(currentTableProvider.notifier)
          .loadTable(widget.tableId, showLoading: false);
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableDataAsync = ref.watch(currentTableProvider);
    final isHost = ref.watch(isHostProvider);
    final theme = Theme.of(context);

    // 1. SECURITY CHECK
    if (!isHost) {
      return _buildAccessDeniedView(theme);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Modify Items',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      // FAB for quick add
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemSheet(context, null),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text("Add Item"),
      ),
      body: tableDataAsync.when(
        data: (tableData) {
          if (tableData == null) return const Center(child: Text('No Data'));
          final items = tableData.items;

          if (items.isEmpty) return _buildEmptyState(theme);

          // Calculate Total for Context
          final total = items.fold<double>(0, (sum, item) => sum + item.price);

          return Column(
            children: [
              // 2. LIVE TOTAL HEADER
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TOTAL BILL",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "${AppConstants.currencySymbol}${total.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. EDITABLE LIST
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    80,
                  ), // Bottom pad for FAB
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildEditCard(context, items[index]);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  // === WIDGETS ===

  Widget _buildAccessDeniedView(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'Host Access Only',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            'No items yet',
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(BuildContext context, BillItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (direction) => _confirmDelete(context, item),
      onDismissed: (direction) => _deleteItem(item.id),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openItemSheet(context, item),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Edit Icon Indicator
                  Icon(
                    Icons.edit_note,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (item.isClaimed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: AppColors.lushGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Claimed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.lushGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Price
                  Text(
                    '${AppConstants.currencySymbol}${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // === LOGIC & SHEETS ===

  Future<bool> _confirmDelete(BuildContext context, BillItem item) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Item?'),
            content: Text(
              "Are you sure you want to remove '${item.description}'?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.onError),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // The Bottom Sheet Editor
  void _openItemSheet(BuildContext context, BillItem? item) {
    final isEditing = item != null;

    if (isEditing) {
      _descriptionController.text = item.description;
      _priceController.text = item.price.toStringAsFixed(2);
    } else {
      _descriptionController.clear();
      _priceController.clear();
    }

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit Item' : 'Add New Item',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Inputs
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g. Extra Fries',
                  prefixIcon: Icon(Icons.edit),
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) =>
                    double.tryParse(val!) == null ? 'Invalid price' : null,
              ),
              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context); // Close sheet first
                      if (isEditing) {
                        _editItem(item.id);
                      } else {
                        _addItem();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add to Bill',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === RIVERPOD ACTIONS ===

  Future<void> _addItem() async {
    try {
      await ref
          .read(currentTableProvider.notifier)
          .addItem(
            description: _descriptionController.text.trim(),
            price: double.parse(_priceController.text),
          );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _editItem(String itemId) async {
    try {
      await ref
          .read(currentTableProvider.notifier)
          .updateItem(
            itemId: itemId,
            description: _descriptionController.text.trim(),
            price: double.parse(_priceController.text),
          );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await ref.read(currentTableProvider.notifier).deleteItem(itemId);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
