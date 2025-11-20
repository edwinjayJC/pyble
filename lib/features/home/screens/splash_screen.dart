import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() async {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      context.go(RoutePaths.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.deepBerry,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/images/pyblelogo.png',
                  height: 140,
                  color: AppColors.snow,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pyble',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: AppColors.snow,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pay Your Piece',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.snow.withOpacity(0.8),
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              const SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.snow,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
