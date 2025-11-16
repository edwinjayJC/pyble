import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.settings,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Coming soon...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
