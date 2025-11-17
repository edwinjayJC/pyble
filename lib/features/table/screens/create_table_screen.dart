import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/table_provider.dart';
import '../models/table_session.dart';

class CreateTableScreen extends ConsumerStatefulWidget {
  const CreateTableScreen({super.key});

  @override
  ConsumerState<CreateTableScreen> createState() => _CreateTableScreenState();
}

class _CreateTableScreenState extends ConsumerState<CreateTableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createTable() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check for active tables first
      final repository = ref.read(tableRepositoryProvider);
      final activeTable = await repository.getActiveTable();

      if (activeTable != null && mounted) {
        // Show dialog to handle existing active table
        final shouldContinue = await _showActiveTableDialog(activeTable);
        if (!shouldContinue) {
          setState(() => _isLoading = false);
          return;
        }
      }

      await ref.read(currentTableProvider.notifier).createTable(
            title: _titleController.text.isNotEmpty
                ? _titleController.text
                : null,
          );

      final tableData = ref.read(currentTableProvider).valueOrNull;
      if (tableData != null && mounted) {
        // Navigate to scan bill screen
        context.go('/table/${tableData.table.id}/scan');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating table: $e'),
            backgroundColor: AppColors.warmSpice,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showActiveTableDialog(TableSession activeTable) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Table Found'),
        content: Text(
          'You already have an active table (${activeTable.code}). '
          'What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'resume'),
            child: const Text('Resume Table'),
          ),
        ],
      ),
    );

    if (result == 'resume' && mounted) {
      // Navigate to the existing table
      context.go('/table/${activeTable.id}/claim');
    }

    return false; // Don't continue with creation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Table'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Icon(
                  Icons.table_restaurant,
                  size: 80,
                  color: AppColors.deepBerry,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Start a New Table',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Create a table to split your restaurant bill with friends',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Table Name (Optional)',
                    hintText: 'e.g., Dinner at Joe\'s',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createTable,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.snow,
                          ),
                        )
                      : const Text('Create Table'),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
