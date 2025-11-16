import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../table/providers/profile_provider.dart';

class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _accepted = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _acceptTerms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(userProfileProvider.notifier).acceptTerms();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to accept terms. Please try again.';
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
        title: const Text('Terms & Conditions'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Terms content
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.lightCrust,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _termsAndConditions,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Checkbox
              CheckboxListTile(
                value: _accepted,
                onChanged: (value) {
                  setState(() {
                    _accepted = value ?? false;
                  });
                },
                title: const Text('I accept the Terms & Conditions'),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.deepBerry,
              ),
              const SizedBox(height: AppSpacing.md),

              // Continue button
              ElevatedButton(
                onPressed: _accepted && !_isLoading ? _acceptTerms : null,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.snow,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const String _termsAndConditions = '''
TERMS AND CONDITIONS OF USE

Last Updated: November 2025

Welcome to Pyble. By using our application, you agree to the following terms and conditions.

1. ACCEPTANCE OF TERMS
By accessing and using Pyble, you accept and agree to be bound by the terms and provision of this agreement.

2. DESCRIPTION OF SERVICE
Pyble is a bill-splitting application that helps users divide restaurant bills among multiple people. The app facilitates reimbursement between users but does not directly process payments.

3. USER ACCOUNTS
You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.

4. PAYMENT PROCESSING
When using in-app payment features, a 4% convenience fee is applied to cover transaction costs. Payments are processed through third-party payment providers.

5. PRIVACY
Your privacy is important to us. Please review our Privacy Policy, which also governs your use of the Service.

6. USER CONDUCT
You agree not to use the service for any unlawful purpose or in any way that could damage, disable, or impair the service.

7. INTELLECTUAL PROPERTY
The Service and its original content, features, and functionality are owned by Pyble and are protected by international copyright, trademark, and other intellectual property laws.

8. LIMITATION OF LIABILITY
Pyble shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the service.

9. CHANGES TO TERMS
We reserve the right to modify these terms at any time. We will notify users of any changes by updating the "Last Updated" date.

10. CONTACT US
If you have any questions about these Terms, please contact us at support@pyble.app.

By using Pyble, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.
''';
