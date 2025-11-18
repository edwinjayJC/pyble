import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/providers/supabase_provider.dart';
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
  TableSession? _activeTable;
  bool _isCheckingForActiveTable = true;

  @override
  void initState() {
    super.initState();
    _checkForActiveTable();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _checkForActiveTable() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isCheckingForActiveTable = false;
          });
        }
        return;
      }

      final repository = ref.read(tableRepositoryProvider);
      final activeTables = await repository.getActiveTables();

      // Only check for tables where the user is the HOST
      final hostedTable = activeTables
          .where((table) => table.hostUserId == currentUser.id)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _activeTable = hostedTable;
          _isCheckingForActiveTable = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingForActiveTable = false;
        });
      }
    }
  }

  Future<void> _createTable() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check if user is already hosting a table
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final repository = ref.read(tableRepositoryProvider);
      final activeTables = await repository.getActiveTables();
      final hostedTable = activeTables
          .where((table) => table.hostUserId == currentUser.id)
          .firstOrNull;

      if (hostedTable != null && mounted) {
        // Show dialog - user is already hosting a table
        final shouldContinue = await _showActiveTableDialog(hostedTable);
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
        title: const Text('Already Hosting a Table'),
        content: Text(
          'You are currently hosting table ${activeTable.code}. '
          'You can only host one table at a time.\n\n'
          'Would you like to return to your hosted table?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'resume'),
            child: const Text('Go to Table'),
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
        child: _isCheckingForActiveTable
            ? const Center(child: CircularProgressIndicator())
            : _activeTable != null
                ? _buildActiveTableView()
                : _buildCreateTableForm(),
      ),
    );
  }

  Widget _buildActiveTableView() {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Icon(
            Icons.info_outline,
            size: 80,
            color: AppColors.warmSpice,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Already Hosting a Table',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You are currently hosting table ${_activeTable!.code}.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You can only host one table at a time. Close your current table to create a new one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.darkFig.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              context.go('/table/${_activeTable!.id}/claim');
            },
            child: const Text('Go to Active Table'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildCreateTableForm() {
    return Padding(
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
    );
  }
}
