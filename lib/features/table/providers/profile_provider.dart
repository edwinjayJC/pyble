import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../models/user_profile.dart';
import '../repository/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient);
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
        UserProfileNotifier.new);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return null;
    }

    try {
      final repository = ref.read(profileRepositoryProvider);
      return await repository.getMyProfile();
    } catch (e) {
      // Profile might not exist yet (new signup)
      return null;
    }
  }

  Future<void> createProfile({
    required String displayName,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('User not authenticated');

    final repository = ref.read(profileRepositoryProvider);
    final profile = await repository.createProfile(
      id: user.id,
      email: user.email ?? '',
      displayName: displayName,
    );

    state = AsyncData(profile);
  }

  Future<void> acceptTerms() async {
    final repository = ref.read(profileRepositoryProvider);
    final profile = await repository.acceptTerms();
    state = AsyncData(profile);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserProvider);
      if (user == null) return null;

      final repository = ref.read(profileRepositoryProvider);
      return await repository.getMyProfile();
    });
  }

  Future<void> deleteAccount() async {
    final repository = ref.read(profileRepositoryProvider);
    await repository.deleteAccount();
    state = const AsyncData(null);
  }
}
