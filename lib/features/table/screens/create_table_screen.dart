import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
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
  late final TextEditingController _titleController;
  late final String _suggestedTitle;

  bool _isLoading = false;
  TableSession? _activeTable;
  bool _checkingTable = true;

  @override
  void initState() {
    super.initState();
    _suggestedTitle = _generateSmartTitle();
    _titleController = TextEditingController();
    _checkForActiveTable();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _generateSmartTitle() {
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now); // "Monday"
    String meal = "Meal";

    if (now.hour < 11) meal = "Breakfast";
    else if (now.hour < 16) meal = "Lunch";
    else if (now.hour < 22) meal = "Dinner";
    else meal = "Late Night";

    return "$day $meal";
  }

  Future<void> _checkForActiveTable() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      final repository = ref.read(tableRepositoryProvider);
      final activeTables = await repository.getActiveTables();

      final hostedTable = activeTables
          .where((table) =>
      table.hostUserId == currentUser.id &&
          (table.status == TableStatus.claiming ||
              table.status == TableStatus.collecting))
          .firstOrNull;

      if (mounted) {
        setState(() {
          _activeTable = hostedTable;
          _checkingTable = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingTable = false);
    }
  }

  Future<void> _createTable() async {
    if (!_formKey.currentState!.validate()) return;

    if (_activeTable != null) {
      _showResumeDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final enteredTitle = _titleController.text.trim();
      await ref.read(currentTableProvider.notifier).createTable(
        title: enteredTitle.isEmpty ? 'Your Table' : enteredTitle,
      );

      final tableData = ref.read(currentTableProvider).valueOrNull;

      if (tableData != null && mounted) {
        context.go('/table/${tableData.table.id}/invite');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResumeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resume Active Session?"),
        content: Text(
            "You are already hosting '${_activeTable?.title ?? 'a table'}'. You must finish that one before starting a new one."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/table/${_activeTable!.id}/claim');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary),
            child: const Text("Go to Active Table"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // 1. FIX: Use Theme Background (Light Crust / Dark Plum)
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
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
                const SizedBox(height: AppSpacing.md),

                // 2. FIX: Icon Container colors
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      // Use Surface color (White/Ink)
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_business,
                        size: 48, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 3. FIX: Text Colors
                Text(
                  'Host a Table',
                  style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You pay the venue. Your friends pay you.\nWe handle the math.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // The Resume Card (If applicable)
                if (_activeTable != null) _buildResumeCard(context),

                // 4. FIX: Input Fields
                if (_activeTable == null) ...[
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Table Name (Optional)',
                      hintText: _suggestedTitle,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontStyle: FontStyle.italic,
                      ),
                      prefixIcon: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.allMd,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // 5. FIX: Button Colors
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_activeTable != null
                        ? () => context.go('/table/${_activeTable!.id}/claim')
                        : _createTable),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 4,
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.allMd),
                    ),
                    child: _isLoading
                        ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary,
                            strokeWidth: 2.5))
                        : Text(
                      _activeTable != null
                          ? 'Resume ${_activeTable!.code}'
                          : 'Start Session',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumeCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Use primary with opacity for the background tint
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Session in Progress",
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  _activeTable?.title ?? "Table ${_activeTable?.code}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
