import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.egg_alt,
      iconColor: AppTheme.primaryColor,
      title: 'Welcome to PoultryPro',
      subtitle:
          'The smart farm manager built for Nigerian poultry farmers. '
          'Track your flocks, expenses, and profits — even offline.',
    ),
    _OnboardingPage(
      icon: Icons.trending_up,
      iconColor: AppTheme.secondaryColor,
      title: 'Know Your Numbers',
      subtitle:
          'See exactly how much each batch costs, what you need to '
          'sell at, and whether you\'re making a profit — per bird.',
    ),
    _OnboardingPage(
      icon: Icons.notifications_active,
      iconColor: AppTheme.accentColor,
      title: 'Never Miss a Vaccination',
      subtitle:
          'Smart alerts tell you when to vaccinate, when mortality '
          'is spiking, and when feed is running low.',
    ),
    _OnboardingPage(
  icon: Icons.cloud_done_outlined,
  iconColor: AppTheme.infoColor,
  title: 'Your Data, Always Safe',
  subtitle:
      'Your farm records stay available offline on your phone. '
      'Upgrade to Pro to automatically back up your data securely '
      'to the cloud and access it anytime.',
),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await context.read<AuthProvider>().completeOnboarding();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _complete,
                child: Text(
                  'Skip',
                  style: AppTheme.bodyMedium
                      .copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    _PageContent(page: _pages[index]),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLG,
                AppTheme.spacingMD,
                AppTheme.spacingLG,
                AppTheme.spacingXL,
              ),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor
                                  .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _complete();
                        }
                      },
                      style: AppTheme.primaryButtonStyle,
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: page.iconColor),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          Text(
            page.title,
            style: AppTheme.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            page.subtitle,
            style: AppTheme.bodyMedium
                .copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}