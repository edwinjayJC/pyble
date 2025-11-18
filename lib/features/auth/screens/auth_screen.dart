import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:email_validator/email_validator.dart';
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
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          ),
                        ),
                      ),
                      Text(
                        'Pyble',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: AppColors.darkFig,
                              fontSize: 60,
                              fontWeight: FontWeight.normal,
                              fontFamily: "Quip",
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pay Your Piece of The Pie',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.darkFig.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 48),
                      const Spacer(),
                      const EmailAuthForm(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with',
                              style: Theme.of(context).textTheme.bodySmall
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
                          await ref
                              .read(userProfileProvider.notifier)
                              .refresh();
                          if (context.mounted) {
                            final profile = ref
                                .read(userProfileProvider)
                                .valueOrNull;
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
                            await ref
                                .read(userProfileProvider.notifier)
                                .refresh();
                            if (context.mounted) {
                              final profile = ref
                                  .read(userProfileProvider)
                                  .valueOrNull;
                              if (profile != null &&
                                  !profile.hasAcceptedTerms) {
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

class EmailAuthForm extends ConsumerStatefulWidget {
  const EmailAuthForm({super.key});

  @override
  ConsumerState<EmailAuthForm> createState() => _EmailAuthFormState();
}

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.result, super.key});

  final PasswordValidationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requirements = [
      _PasswordRule(label: '1 uppercase letter', isMet: result.hasUppercase),
      _PasswordRule(label: '1 lowercase letter', isMet: result.hasLowercase),
      _PasswordRule(label: '1 number', isMet: result.hasNumber),
      _PasswordRule(label: '1 special character', isMet: result.hasSpecial),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StrengthMeterBar(strength: result.strength),
        const SizedBox(height: 6),
        Text(
          _strengthLabel(result.strength),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...requirements.map((rule) => _RuleRow(rule: rule)),
      ],
    );
  }

  String _strengthLabel(double strength) {
    if (strength <= 0.25) return 'Very weak';
    if (strength <= 0.5) return 'Keep going';
    if (strength <= 0.75) return 'Almost there';
    return 'Strong password';
  }
}

class _StrengthMeterBar extends StatelessWidget {
  const _StrengthMeterBar({required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    final clampedStrength = strength.clamp(0.0, 1.0);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.paleGray,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clampedStrength == 0 ? 0.02 : clampedStrength,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green],
            ),
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    );
  }
}

class _PasswordRule {
  final String label;
  final bool isMet;

  const _PasswordRule({required this.label, required this.isMet});
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final _PasswordRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = rule.isMet ? AppColors.lushGreen : AppColors.disabledText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            rule.isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule.label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordValidationResult {
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecial;

  const PasswordValidationResult({
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecial,
  });

  const PasswordValidationResult.empty()
    : hasUppercase = false,
      hasLowercase = false,
      hasNumber = false,
      hasSpecial = false;

  factory PasswordValidationResult.fromPassword(String value) {
    final uppercase = RegExp(r'[A-Z]').hasMatch(value);
    final lowercase = RegExp(r'[a-z]').hasMatch(value);
    final number = RegExp(r'[0-9]').hasMatch(value);
    final specialPattern = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\\/=+;`~]');
    final special = specialPattern.hasMatch(value) || value.contains("'");

    return PasswordValidationResult(
      hasUppercase: uppercase,
      hasLowercase: lowercase,
      hasNumber: number,
      hasSpecial: special,
    );
  }

  double get strength => satisfiedCount / 4;

  int get satisfiedCount {
    return [
      hasUppercase,
      hasLowercase,
      hasNumber,
      hasSpecial,
    ].where((element) => element).length;
  }

  bool get allRequirementsMet => satisfiedCount == 4;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PasswordValidationResult &&
        other.hasUppercase == hasUppercase &&
        other.hasLowercase == hasLowercase &&
        other.hasNumber == hasNumber &&
        other.hasSpecial == hasSpecial;
  }

  @override
  int get hashCode =>
      hasUppercase.hashCode ^
      hasLowercase.hashCode ^
      hasNumber.hashCode ^
      hasSpecial.hashCode;
}

class _EmailAuthFormState extends ConsumerState<EmailAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSigningIn = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  PasswordValidationResult _passwordResult =
      const PasswordValidationResult.empty();

  @override
  void dispose() {
    _passwordController.removeListener(_handlePasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handlePasswordChanged);
  }

  void _handlePasswordChanged() {
    final result = PasswordValidationResult.fromPassword(
      _passwordController.text,
    );
    if (result == _passwordResult) return;
    setState(() {
      _passwordResult = result;
    });
  }

  void _toggleMode() {
    setState(() {
      _isSigningIn = !_isSigningIn;
    });
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (_isSigningIn) {
      return null;
    }
    final result = PasswordValidationResult.fromPassword(value);
    if (!result.allRequirementsMet) {
      return 'Password must include uppercase, lowercase, number, and special character';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = ref.read(supabaseClientProvider).auth;
    final email = _emailController.text.trim();

    try {
      if (_isSigningIn) {
        await auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );
        await _handlePostAuth();
      } else {
        final response = await auth.signUp(
          email: email,
          password: _passwordController.text,
          data: {'full_name': _nameController.text.trim()},
        );

        if (!mounted) return;
        if (response.session == null) {
          final encodedEmail = Uri.encodeComponent(email);
          setState(() => _isLoading = false);
          context.go('${RoutePaths.verifyEmail}?email=$encodedEmail');
          return;
        }

        await _handlePostAuth();
      }
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePostAuth() async {
    ref.invalidate(currentUserProvider);
    ref.invalidate(currentSessionProvider);
    await ref.read(userProfileProvider.notifier).refresh();
    if (!mounted) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null && !profile.hasAcceptedTerms) {
      context.go(RoutePaths.terms);
    } else {
      context.go(RoutePaths.home);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!EmailValidator.validate(email)) {
      _showMessage(
        'Enter a valid email to reset your password.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(email);
      _showMessage('Password reset email sent. Check your inbox.');
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('Unable to send reset email right now.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.warmSpice : null,
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      prefixIcon: const Icon(Icons.lock_outline),
      labelText: label,
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        onPressed: onToggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email address',
            ),
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty ||
                  !EmailValidator.validate(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (!_isSigningIn) ...[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                labelText: 'Full name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: _isSigningIn
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            decoration: _passwordDecoration(
              label: 'Password',
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: _passwordValidator,
          ),
          if (!_isSigningIn) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: _passwordDecoration(
                label: 'Confirm password',
                obscure: _obscureConfirmPassword,
                onToggle: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            PasswordStrengthMeter(result: _passwordResult),
          ],
          if (_isSigningIn)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: const Text('Forgot password?'),
              ),
            )
          else
            const SizedBox(height: 8),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.snow,
                    ),
                  )
                : Text(_isSigningIn ? 'Sign In' : 'Create Account'),
          ),
          TextButton(
            onPressed: _isLoading ? null : _toggleMode,
            child: Text(
              _isSigningIn
                  ? 'Need an account? Sign up'
                  : 'Already have an account? Sign in',
            ),
          ),
        ],
      ),
    );
  }
}
