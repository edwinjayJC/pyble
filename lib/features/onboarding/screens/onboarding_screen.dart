import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.restaurant_menu,
      title: 'Welcome to Pyble',
      description:
          'Split restaurant bills easily with friends. No more awkward calculations or IOUs.',
    ),
    OnboardingPage(
      icon: Icons.qr_code_scanner,
      title: 'Scan & Split',
      description:
          'Scan your bill with AI-powered OCR, or add items manually. Everyone claims what they had.',
    ),
    OnboardingPage(
      icon: Icons.payments,
      title: 'Get Reimbursed',
      description:
          'Participants pay you back in-app or outside. Track who owes what in real-time.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await prefs.setBool('${AppConstants.tutorialSeenKey}_$userId', true);
    } else {
      await prefs.setBool(AppConstants.tutorialSeenKey, true);
    }
    if (mounted) {
      context.go(RoutePaths.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            _buildIndicators(),
            const SizedBox(height: 24),
            _buildButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.lightBerry,
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 60, color: AppColors.deepBerry),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.darkFig,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.darkFig.withOpacity(0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.deepBerry
                : AppColors.lightBerry,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          if (_currentPage == _pages.length - 1)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _completeOnboarding,
                child: const Text('Get Started'),
              ),
            )
          else
            Row(
              children: [
                TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: AppColors.darkFig.withOpacity(0.6)),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
