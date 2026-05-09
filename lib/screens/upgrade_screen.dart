import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Upgrade to Poultry Pro')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          Text('Upgrade to Poultry Pro', style: AppTheme.headingMedium),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            SubscriptionService.upgradeMessage,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLG),
          const _PlanCard(
            title: 'Free',
            subtitle: 'For getting started',
            color: AppTheme.textSecondary,
            benefits: [
              'Manage 1 flock',
              'Track basic flock records',
              'Record expenses and sales',
              'Backup and restore local data',
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          const _PlanCard(
            title: 'Pro',
            subtitle: 'For growing poultry businesses',
            color: AppTheme.primaryColor,
            benefits: [
              'Manage unlimited flocks',
              'Advanced reports',
              'Reminders',
              'Business insights',
            ],
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment coming soon', style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Pro checkout is not enabled yet. Contact/WhatsApp upgrade support will be added before payments go live.',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp/contact coming soon'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<String> benefits;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: color),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.headingSmall),
                      Text(subtitle, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ...benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: color),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(child: Text(benefit)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
