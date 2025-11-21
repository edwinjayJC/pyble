import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Core Imports
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

  @override
  void initState() {
    super.initState();
    _suggestedTitle = _generateSmartTitle();
    _titleController = TextEditingController(); // Start empty to let hint show

    // Non-blocking check for existing sessions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForActiveTable();
    });
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

    if (now.hour < 11)
      meal = "Breakfast";
    else if (now.hour < 16)
      meal = "Lunch";
    else if (now.hour < 22)
      meal = "Dinner";
    else
      meal = "Late Night";

    return "$day $meal";
  }

  Future<void> _checkForActiveTable() async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      final repository = ref.read(tableRepositoryProvider);
      final activeTables = await repository.getActiveTables();

      final hostedTable = activeTables
          .where(
            (table) =>
                table.hostUserId == currentUser.id &&
                (table.status == TableStatus.claiming ||
                    table.status == TableStatus.collecting),
          )
          .firstOrNull;

      if (mounted && hostedTable != null) {
        setState(() {
          _activeTable = hostedTable;
        });
      }
    } catch (e) {
      // Fail silently
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
      // UX FIX: If empty, use the Smart Suggestion as the actual title
      final finalTitle = enteredTitle.isEmpty ? _suggestedTitle : enteredTitle;

      await ref
          .read(currentTableProvider.notifier)
          .createTable(title: finalTitle);

      final tableData = ref.read(currentTableProvider).valueOrNull;

      if (tableData != null && mounted) {
        // FLOW UPDATE: Go to INVITE (Lobby), not Scan.
        // This allows the "Pre-Event" creation flow.
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

  void _showResumeDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resume Active Event?"),
        content: Text(
          "You already have an open event: '${_activeTable?.title ?? 'Untitled'}'.\n\nYou must finish or cancel that one before starting a new one.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Resume goes to Invite/Lobby to check on guests
              context.go('/table/${_activeTable!.id}/invite');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text("Go to Event"),
          ),
        ],
      ),
    );
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
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
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
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 40),

                              // The Resume Card
                              if (_activeTable != null)
                                _buildResumeCard(context),

                              // 3. Input Fields
                              if (_activeTable == null) ...[
                                TextFormField(
                                  controller: _titleController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Event Name',
                                    hintText: _suggestedTitle,
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    hintStyle: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.4),
                                      fontStyle: FontStyle.normal,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.edit_outlined,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7),
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
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],

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
            _buildCreateFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateFooter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : (_activeTable != null
                      ? () => context.go('/table/${_activeTable!.id}/invite')
                      : _createTable),
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
                : Text(
                    _activeTable != null
                        ? 'Resume ${_activeTable!.code}'
                        : 'Create & Invite',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: AppRadius.allMd,
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Event in Progress",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _activeTable?.title ?? "Table ${_activeTable?.code}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
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
