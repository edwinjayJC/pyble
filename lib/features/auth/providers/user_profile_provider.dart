import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../models/user_profile.dart';
import '../repository/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserRepository(apiClient: apiClient);
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(() {
  return UserProfileNotifier();
});

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final repository = ref.read(userRepositoryProvider);
    try {
      return await repository.getProfile(user.id);
    } catch (e) {
      // If profile doesn't exist, create one
      return await repository.createProfile(
        userId: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            user.email?.split('@').first ??
            'User',
      );
    }
  }

  Future<void> acceptTerms() async {
    final currentProfile = state.valueOrNull;
    if (currentProfile == null) return;

    final repository = ref.read(userRepositoryProvider);
    final updatedProfile = await repository.acceptTerms(currentProfile.id);
    state = AsyncValue.data(updatedProfile);
  }

  Future<void> updateDisplayName(String name) async {
    final currentProfile = state.valueOrNull;
    if (currentProfile == null) return;

    final repository = ref.read(userRepositoryProvider);
    final updatedProfile = await repository.updateProfile(
      currentProfile.id,
      displayName: name,
    );
    state = AsyncValue.data(updatedProfile);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
