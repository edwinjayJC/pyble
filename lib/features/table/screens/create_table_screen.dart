import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/route_names.dart';
import '../providers/table_provider.dart';

class CreateTableScreen extends ConsumerStatefulWidget {
  const CreateTableScreen({super.key});

  @override
  ConsumerState<CreateTableScreen> createState() => _CreateTableScreenState();
}

class _CreateTableScreenState extends ConsumerState<CreateTableScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _createTable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check for active table first
      await ref.read(currentTableProvider.notifier).checkForActiveTable();
      final activeTable = ref.read(currentTableProvider).value;

      if (activeTable != null) {
        if (mounted) {
          _showActiveTableDialog(activeTable.id);
        }
        return;
      }

      // Create new table
      final table = await ref.read(currentTableProvider.notifier).createTable();

      if (mounted) {
        // Navigate to scan bill screen
        context.pushReplacementNamed(
          RouteNames.scanBill,
          pathParameters: {'tableId': table.id},
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create table. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showActiveTableDialog(String tableId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Table Found'),
        content: const Text(
          'You already have an active table. Would you like to continue with that table or start a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pushReplacementNamed(
                RouteNames.hostInvite,
                pathParameters: {'tableId': tableId},
              );
            },
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Cancel old table and create new one
            },
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Table'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              const Icon(
                Icons.table_restaurant,
                size: 100,
                color: AppColors.deepBerry,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Create a New Table',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                'Start a new bill-splitting session. You\'ll be the host and can invite others to join.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.disabledText,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.lightWarmSpice,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.warmSpice),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Create button
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
            ],
          ),
        ),
      ),
    );
  }
}
