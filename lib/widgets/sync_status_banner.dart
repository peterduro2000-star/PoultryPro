import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Subtle top banner that shows sync state.
/// Renders nothing when sync is idle and healthy.
/// Drop this anywhere above a Scaffold body.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, sync, _) {
        if (sync.isHealthy && sync.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final Color bg;
        final Color fg;
        final IconData icon;
        final String message;

        if (sync.isSyncing) {
          bg      = AppTheme.infoColor.withValues(alpha: 0.12);
          fg      = AppTheme.infoColor;
          icon    = Icons.sync;
          message = 'Backing up your data…';
        } else if (sync.hasError) {
          bg      = AppTheme.errorColor.withValues(alpha: 0.10);
          fg      = AppTheme.errorColor;
          icon    = Icons.cloud_off_outlined;
          message = 'Backup failed — will retry automatically';
        } else if (sync.pendingCount > 0) {
          bg      = AppTheme.warningColor.withValues(alpha: 0.12);
          fg      = AppTheme.warningColor;
          icon    = Icons.cloud_upload_outlined;
          message = '${sync.pendingCount} change${sync.pendingCount == 1 ? '' : 's'} waiting to back up';
        } else {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: bg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: 6,
          ),
          child: Row(
            children: [
              sync.isSyncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Icon(icon, size: 14, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTheme.bodySmall.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sync.hasError)
                GestureDetector(
                  onTap: () => context.read<SyncService>().syncNow(),
                  child: Text(
                    'Retry',
                    style: AppTheme.bodySmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}