import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/user_profile_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                        child: Center(
                            child: Image.asset(
                              'assets/images/pie.png',
                              height: 120,
                            )),
                      ),
                      Text(
                        'pyble',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: AppColors.deepBerry,
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Qilka-Bold"
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Split bills with friends',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.darkFig.withOpacity(0.7),
                            ),
                      ),
                      const SizedBox(height: 48),
                      const Spacer(),
                      SupaEmailAuth(
                        redirectTo: null,
                        onSignInComplete: (response) {
                          context.go(RoutePaths.home);
                        },
                        onSignUpComplete: (response) {
                          context.go(RoutePaths.home);
                        },
                        metadataFields: [
                          MetaDataField(
                            prefixIcon: const Icon(Icons.person),
                            label: 'Full Name',
                            key: 'full_name',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.darkFig.withOpacity(0.5),
                                  ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SupaSocialsAuth(
                        socialProviders: const [
                          OAuthProvider.google,
                          OAuthProvider.apple,
                        ],
                        colored: true,
                        redirectUrl: 'pyble://login-callback',
                        onSuccess: (session) async {
                          // Invalidate providers to pick up the new auth state
                          ref.invalidate(currentUserProvider);
                          ref.invalidate(currentSessionProvider);
                          // Ensure user profile is fetched/created before navigating
                          await ref.read(userProfileProvider.notifier).refresh();
                          if (context.mounted) {
                            final profile = ref.read(userProfileProvider).valueOrNull;
                            if (profile != null && !profile.hasAcceptedTerms) {
                              context.go(RoutePaths.terms);
                            } else {
                              context.go(RoutePaths.home);
                            }
                          }
                        },
                        onError: (error) async {
                          // Check if user was actually authenticated despite the error
                          // (can happen with trigger errors that don't prevent user creation)
                          ref.invalidate(currentUserProvider);
                          ref.invalidate(currentSessionProvider);
                          final session = ref.read(currentSessionProvider);

                          if (session != null) {
                            // User is authenticated, proceed with normal flow
                            await ref.read(userProfileProvider.notifier).refresh();
                            if (context.mounted) {
                              final profile = ref.read(userProfileProvider).valueOrNull;
                              if (profile != null && !profile.hasAcceptedTerms) {
                                context.go(RoutePaths.terms);
                              } else {
                                context.go(RoutePaths.home);
                              }
                            }
                          } else {
                            // Actual error, show message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $error'),
                                  backgroundColor: AppColors.warmSpice,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
