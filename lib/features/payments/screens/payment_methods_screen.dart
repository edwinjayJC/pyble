import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../models/payment_method.dart';
import '../providers/payment_methods_provider.dart';
import 'payment_method_webview_screen.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: methodsAsync.when(
        data: (methods) => _buildList(context, ref, methods),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.deepBerry)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.warmSpice),
              const SizedBox(height: AppSpacing.sm),
              Text('Unable to load methods: $e'),
              TextButton(
                onPressed: () => ref.read(paymentMethodsProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_card),
          label: const Text('Add payment method'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          ),
          onPressed: () => _startAddCard(context, ref),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<PaymentMethod> methods,
  ) {
    if (methods.isEmpty) {
      return const Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text('No payment methods yet. Add a card to pay faster next time.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentMethodsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 80),
        itemCount: methods.length,
        itemBuilder: (context, index) {
          final method = methods[index];
          return _PaymentMethodTile(
            method: method,
            onSetDefault: () =>
                ref.read(paymentMethodsProvider.notifier).setDefault(method.id),
            onEditLabel: () => _editLabel(context, ref, method),
            onDelete: () =>
                ref.read(paymentMethodsProvider.notifier).delete(method.id),
          );
        },
      ),
    );
  }

  Future<void> _startAddCard(BuildContext context, WidgetRef ref) async {
    try {
      final resp = await ref
          .read(paymentMethodsProvider.notifier)
          .addCard(makeDefault: true);
      if (!context.mounted) return;
      await context.push(
        PaymentMethodWebviewScreen.routePath,
        extra: resp.redirectUrl,
      );
      await ref.read(paymentMethodsProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add card failed: $e')),
        );
      }
    }
  }

  Future<void> _editLabel(
    BuildContext context,
    WidgetRef ref,
    PaymentMethod method,
  ) async {
    final controller = TextEditingController(text: method.label ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nickname'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(paymentMethodsProvider.notifier).updateLabel(method.id, result);
    }
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.onSetDefault,
    required this.onEditLabel,
    required this.onDelete,
  });

  final PaymentMethod method;
  final VoidCallback onSetDefault;
  final VoidCallback onEditLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Icon(
            method.type == PaymentMethodType.card ? Icons.credit_card : Icons.account_balance,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(method.label ?? method.provider.apiValue),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'default':
                onSetDefault();
                break;
              case 'edit':
                onEditLabel();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            if (!method.isDefault)
              const PopupMenuItem(value: 'default', child: Text('Set as default')),
            const PopupMenuItem(value: 'edit', child: Text('Edit label')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Remove'),
            ),
          ],
        ),
        onTap: method.isDefault ? null : onSetDefault,
      ),
    );
  }

  String get _title {
    final brand = method.brand ?? method.provider.apiValue.toUpperCase();
    final suffix = method.last4 != null ? '•••• ${method.last4}' : '';
    final defaultBadge = method.isDefault ? ' (Default)' : '';
    return '$brand $suffix$defaultBadge';
  }
}
