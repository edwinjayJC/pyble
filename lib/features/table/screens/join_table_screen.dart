import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/table_provider.dart';

class JoinTableScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinTableScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinTableScreen> createState() => _JoinTableScreenState();
}

class _JoinTableScreenState extends ConsumerState<JoinTableScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      // Auto-join if code provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinTable();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinTable() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-character code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(currentTableProvider.notifier).joinTable(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined table!'),
            backgroundColor: AppColors.lushGreen,
          ),
        );
        // Navigate to table view (will be implemented in Phase 2)
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to join table. Please check the code and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Table'),
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
                Icons.group_add,
                size: 80,
                color: AppColors.deepBerry,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Join a Table',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                'Enter the 6-character code shared by the host',
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

              // Code input
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'ABC123',
                  counterText: '',
                ),
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Join button
              ElevatedButton(
                onPressed: _isLoading ? null : _joinTable,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.snow,
                        ),
                      )
                    : const Text('Join Table'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
