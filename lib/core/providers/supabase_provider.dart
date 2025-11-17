import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser;
});

final currentSessionProvider = Provider<Session?>((ref) {
  // Watch the auth state stream to react to auth changes (e.g., OAuth redirects)
  ref.watch(authStateProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentSession;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  // Watch the auth state stream to react to auth changes (e.g., OAuth redirects)
  ref.watch(authStateProvider);
  // Then check the current session
  final session = ref.watch(currentSessionProvider);
  return session != null;
});
