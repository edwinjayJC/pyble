import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import 'supabase_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ApiClient(supabase: supabase);
});
