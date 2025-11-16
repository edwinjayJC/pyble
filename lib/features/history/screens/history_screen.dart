import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'History',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your past tables will appear here...',
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
