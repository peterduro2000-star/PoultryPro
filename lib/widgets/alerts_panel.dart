import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/alerts_provider.dart';
import '../services/alerts_service.dart';
import '../theme/app_theme.dart';

class AlertsPanel extends StatelessWidget {
  final String? flockId; // null = show all alerts across farm

  const AlertsPanel({super.key, this.flockId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        final alerts = flockId != null
            ? provider.alertsForFlock(flockId!)
            : provider.allAlerts;

        if (alerts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD),
              child: Row(
                children: [
                  Icon(
                    provider.hasCritical
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                    size: 18,
                    color: provider.hasCritical
                        ? AppTheme.errorColor
                        : AppTheme.warningColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${alerts.length} Alert${alerts.length == 1 ? '' : 's'}',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: provider.hasCritical
                          ? AppTheme.errorColor
                          : AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            ...alerts.map((alert) => _AlertCard(alert: alert)),
          ],
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final FarmAlert alert;
  const _AlertCard({required this.alert});

  Color get _color {
    switch (alert.level) {
      case AlertLevel.critical:
        return AppTheme.errorColor;
      case AlertLevel.warning:
        return AppTheme.warningColor;
      case AlertLevel.info:
        return AppTheme.infoColor;
    }
  }

  IconData get _icon {
    switch (alert.level) {
      case AlertLevel.critical:
        return Icons.error_outline;
      case AlertLevel.warning:
        return Icons.warning_amber_outlined;
      case AlertLevel.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        0,
        AppTheme.spacingMD,
        AppTheme.spacingSM,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color, size: 20),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}