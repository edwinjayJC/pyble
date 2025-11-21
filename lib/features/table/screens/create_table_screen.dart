import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Core Imports
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/table_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _suggestedTitle = _generateSmartTitle();
    // Start empty to let the hint text do the work visually
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _generateSmartTitle() {
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now); // "Friday"
    String meal = "Gathering";

    if (now.hour < 11) meal = "Breakfast";
    else if (now.hour < 16) meal = "Lunch";
    else if (now.hour < 22) meal = "Dinner";
    else meal = "Late Night";

    return "$day $meal";
  }

  Future<void> _createTable() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final enteredTitle = _titleController.text.trim();
      // UX FIX: If empty, use the Smart Suggestion as the actual title
      final finalTitle = enteredTitle.isEmpty ? _suggestedTitle : enteredTitle;

      // Create the table (No pre-checks for existing tables anymore)
      await ref.read(currentTableProvider.notifier).createTable(
        title: finalTitle,
      );

      final tableData = ref.read(currentTableProvider).valueOrNull;

      if (tableData != null && mounted) {
        // FLOW: Go to INVITE (Lobby) immediately to allow pre-planning
        context.go('/table/${tableData.table.id}/invite');
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
        bottom: false, // Let the footer handle the bottom safe area
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.md),

                              // 1. Icon Container
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.calendar_today_rounded,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // 2. Headline
                              Text(
                                'Plan New Event',
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Set up the table now.\nInvite friends before you even arrive.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 48),

                              // 3. Input Fields
                              TextFormField(
                                controller: _titleController,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Event Name',
                                  hintText: _suggestedTitle,
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                    fontStyle: FontStyle.normal,
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
                              const SizedBox(height: 12),
                              Text(
                                "Leave empty to name it '$_suggestedTitle'",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5)
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. Sticky Footer
            _buildCreateFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateFooter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), // Extra padding for safe area manually if needed
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createTable,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.allMd,
              ),
            ),
            child: _isLoading
                ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: theme.colorScheme.onPrimary,
                strokeWidth: 2.5,
              ),
            )
                : const Text(
              'Create & Invite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}