import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:email_validator/email_validator.dart';

// Core Imports
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/user_profile_provider.dart';

// ==========================================
// 1. THE MAIN SCREEN
// ==========================================

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Uses LightCrust in Light Mode, DarkPlum in Dark Mode (via AppTheme)
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      const SizedBox(height: 60),

                      // Brand Header
                      _buildBrandHeader(context),

                      const SizedBox(height: 48),

                      // Social Sign-in First
                      _buildSocialButtons(context, ref, isDark, colorScheme),
                      const SizedBox(height: 24),

                      // Divider before email form
                      _buildSocialAuthDivider(context),
                      const SizedBox(height: 24),

                      // Email Form now follows
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: isDark
                              ? Border.all(color: AppColors.darkBorder, width: 1)
                              : null,
                        ),
                        child: const EmailAuthForm(),
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

  Widget _buildBrandHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Image.asset(
            'assets/images/pyblelogo.png',
            height: 100,
            // Optional: If your logo is black text, invert it for dark mode
            // color: theme.brightness == Brightness.dark ? Colors.white : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'pyble',
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 52,
            fontWeight: FontWeight.normal,
            fontFamily: "Quip",
            // Color is automatically handled by displayLarge in AppTheme
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pay Your Piece',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.primary, // DeepBerry vs BrightBerry
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.snow,
            foregroundColor: colorScheme.onSurface,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
      ),
      child: SupaSocialsAuth(
        socialProviders: const [
          OAuthProvider.google,
          OAuthProvider.azure,
        ],
        colored: true,
        redirectUrl: 'pyble://login-callback',
        onSuccess: (session) => _handleAuthSuccess(context, ref),
        onError: (error) => _handleAuthError(context, ref, error),
      ),
    );
  }

  Widget _buildSocialAuthDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or sign in with email',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
        Expanded(child: Divider(color: theme.dividerColor)),
      ],
    );
  }

  Future<void> _handleAuthSuccess(BuildContext context, WidgetRef ref) async {
    ref.invalidate(currentUserProvider);
    ref.invalidate(currentSessionProvider);
    await ref.read(userProfileProvider.notifier).refresh();

    if (context.mounted) {
      _navigateBasedOnProfile(context, ref);
    }
  }

  Future<void> _handleAuthError(BuildContext context, WidgetRef ref, Object error) async {
    ref.invalidate(currentUserProvider);
    ref.invalidate(currentSessionProvider);
    final session = ref.read(currentSessionProvider);

    if (session != null) {
      await ref.read(userProfileProvider.notifier).refresh();
      if (context.mounted) _navigateBasedOnProfile(context, ref);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateBasedOnProfile(BuildContext context, WidgetRef ref) {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null && !profile.hasAcceptedTerms) {
      context.go(RoutePaths.terms);
    } else {
      context.go(RoutePaths.home);
    }
  }
}

// ==========================================
// 2. THE ANIMATED FORM
// ==========================================

class EmailAuthForm extends ConsumerStatefulWidget {
  const EmailAuthForm({super.key});

  @override
  ConsumerState<EmailAuthForm> createState() => _EmailAuthFormState();
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
  PasswordValidationResult _passwordResult = const PasswordValidationResult.empty();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handlePasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_handlePasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handlePasswordChanged() {
    if (_isSigningIn) return;
    final result = PasswordValidationResult.fromPassword(_passwordController.text);
    if (result == _passwordResult) return;
    setState(() => _passwordResult = result);
  }

  void _toggleMode() {
    setState(() {
      _isSigningIn = !_isSigningIn;
    });
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
      _showMessage('Enter a valid email first.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(email);
      _showMessage('Password reset email sent.');
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('Unable to send reset email.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : AppColors.lushGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // We rely on AppTheme's InputDecorationTheme.
    // DO NOT override fillColor here, or it will break Dark Mode.

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Card Header
          Text(
            _isSigningIn ? 'Welcome Back' : 'Create Account',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 2. Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email address',
            ),
            validator: (value) =>
            (value == null || !EmailValidator.validate(value.trim()))
                ? 'Please enter a valid email'
                : null,
          ),
          const SizedBox(height: 16),

          // 3. Animated Name Field (Sign Up Only)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isSigningIn
                ? const SizedBox.shrink()
                : Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: 'Full name',
                  ),
                  validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // 4. Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: _isSigningIn ? const [AutofillHints.password] : const [AutofillHints.newPassword],
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Required';
              if (!_isSigningIn) {
                if (!PasswordValidationResult.fromPassword(val).allRequirementsMet) {
                  return 'Password is too weak';
                }
              }
              return null;
            },
          ),

          // 5. Animated Confirm Password & Strength (Sign Up Only)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isSigningIn
                ? const SizedBox.shrink()
                : Column(
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_reset),
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 16),
                if (_passwordController.text.isNotEmpty)
                  PasswordStrengthMeter(result: _passwordResult),
              ],
            ),
          ),

          // 6. Forgot Password Link
          if (_isSigningIn)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: Text(
                  'Forgot password?',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            )
          else
            const SizedBox(height: 24),

          // 7. Submit Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: theme.colorScheme.onPrimary)
              )
                  : Text(
                _isSigningIn ? 'Sign In' : 'Create Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 8. Toggle Mode
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isSigningIn ? "Don't have an account?" : "Already have an account?",
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              TextButton(
                onPressed: _isLoading ? null : _toggleMode,
                child: Text(
                  _isSigningIn ? 'Sign up' : 'Sign in',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. HELPER CLASSES
// ==========================================

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
    if (value.isEmpty) return const PasswordValidationResult.empty();
    final uppercase = RegExp(r'[A-Z]').hasMatch(value);
    final lowercase = RegExp(r'[a-z]').hasMatch(value);
    final number = RegExp(r'[0-9]').hasMatch(value);
    final special = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\\/=+;`~]').hasMatch(value) || value.contains("'");

    return PasswordValidationResult(
      hasUppercase: uppercase,
      hasLowercase: lowercase,
      hasNumber: number,
      hasSpecial: special,
    );
  }

  double get strength => satisfiedCount / 4;
  int get satisfiedCount => [hasUppercase, hasLowercase, hasNumber, hasSpecial].where((e) => e).length;
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
  int get hashCode => hasUppercase.hashCode ^ hasLowercase.hashCode ^ hasNumber.hashCode ^ hasSpecial.hashCode;
}

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.result, super.key});
  final PasswordValidationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final requirements = [
      _PasswordRule(label: '1 Uppercase letter', isMet: result.hasUppercase),
      _PasswordRule(label: '1 Lowercase letter', isMet: result.hasLowercase),
      _PasswordRule(label: '1 Number', isMet: result.hasNumber),
      _PasswordRule(label: '1 Special character', isMet: result.hasSpecial),
    ];

    final strengthColor = _strengthColor(result.strength, isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StrengthMeterBar(strength: result.strength, color: strengthColor),
        const SizedBox(height: 8),
        Text(
          _strengthLabel(result.strength),
          style: theme.textTheme.bodySmall?.copyWith(
            color: strengthColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...requirements.map((rule) => _RuleRow(rule: rule)),
      ],
    );
  }

  String _strengthLabel(double strength) {
    if (strength <= 0.25) return 'Weak';
    if (strength <= 0.5) return 'Fair';
    if (strength <= 0.75) return 'Good';
    return 'Strong';
  }

  Color _strengthColor(double strength, bool isDark) {
    if (strength <= 0.25) return isDark ? AppColors.brightWarmSpice : AppColors.warmSpice;
    if (strength <= 0.75) return const Color(0xFFE6B800);
    return isDark ? AppColors.brightGreen : AppColors.lushGreen;
  }
}

class _StrengthMeterBar extends StatelessWidget {
  const _StrengthMeterBar({required this.strength, required this.color});
  final double strength;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedStrength = strength.clamp(0.0, 1.0);

    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.dividerColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clampedStrength == 0 ? 0.05 : clampedStrength,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});
  final _PasswordRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = isDark ? AppColors.brightGreen : AppColors.lushGreen;
    final inactiveColor = theme.disabledColor;

    final color = rule.isMet ? activeColor : inactiveColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              rule.isMet ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey(rule.isMet),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: rule.isMet ? theme.colorScheme.onSurface : inactiveColor,
                fontWeight: rule.isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRule {
  final String label;
  final bool isMet;
  const _PasswordRule({required this.label, required this.isMet});
}
