import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../models/payment_method.dart';
import '../services/payment_methods_service.dart';

final paymentMethodsServiceProvider =
    Provider<PaymentMethodsService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentMethodsService(apiClient: apiClient);
});

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsNotifier, AsyncValue<List<PaymentMethod>>>(
        (ref) {
  final service = ref.watch(paymentMethodsServiceProvider);
  return PaymentMethodsNotifier(service: service);
});

class PaymentMethodsNotifier
    extends StateNotifier<AsyncValue<List<PaymentMethod>>> {
  PaymentMethodsNotifier({required this.service})
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final PaymentMethodsService service;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final methods = await service.list();
      state = AsyncValue.data(_sort(methods));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<AddPaymentMethodInitResponse> addCard({
    required bool makeDefault,
    String? label,
  }) async {
    final resp = await service.addCard(makeDefault: makeDefault, label: label);
    return resp;
  }

  Future<void> setDefault(String id) async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final updated = await service.setDefault(id);
      final list = (current ?? [])
          .map((m) => m.id == updated.id
              ? updated
              : m.copyWith(isDefault: false))
          .toList();
      state = AsyncValue.data(_sort(list));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateLabel(String id, String label) async {
    final current = state.valueOrNull ?? [];
    try {
      final updated = await service.updateLabel(id, label);
      final list =
          current.map((m) => m.id == updated.id ? updated : m).toList();
      state = AsyncValue.data(_sort(list));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(String id) async {
    final current = state.valueOrNull ?? [];
    state = const AsyncValue.loading();
    try {
      await service.delete(id);
      final list = current.where((m) => m.id != id).toList();
      state = AsyncValue.data(_sort(list));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  static List<PaymentMethod> _sort(List<PaymentMethod> methods) {
    final sorted = [...methods];
    sorted.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (b.isDefault && !a.isDefault) return 1;
      return 0;
    });
    return sorted;
  }
}
