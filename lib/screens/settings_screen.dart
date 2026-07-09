import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/flock_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/daily_record_provider.dart';
import '../providers/license_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'backup_screen.dart';
import 'sign_in_screen.dart';

// ============================================================================
//   Unified Section Widget
// ============================================================================

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Widget child;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.headingSmall),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
//   Main Settings Screen
// ============================================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ─── Data Actions ──────────────────────────────────────────────────────────

  Future<void> _syncNow(BuildContext context) async {
    try {
      await context.read<SyncService>().syncNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Widget _buildSyncButton(BuildContext context, SyncService sync) {
    if (sync.isSyncing) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return TextButton.icon(
      onPressed: () => _syncNow(context),
      icon: const Icon(Icons.sync_rounded, size: 16),
      label: const Text('Sync'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
      ),
    );
  }

  String _formatExpiry(DateTime expiry) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${expiry.day} ${months[expiry.month - 1]} ${expiry.year}';
  }

  Future<void> _backupData(BuildContext context) async {
    try {
      final data = await DatabaseService().exportAllToJson();
      final jsonString = jsonEncode(data);

      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(
        '${dir.path}/poultry_pro_backup_'
        '${DateTime.now().millisecondsSinceEpoch}.json',
      );

      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Poultry Pro Backup — '
            '${DateTime.now().toIso8601String().split('T').first}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup saved! Send this file to yourself on WhatsApp.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text(
            'This will DELETE all current data and replace it '
            'with the backup.\n\nAre you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Restore', style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await DatabaseService().importAllFromJson(data);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear ALL Data?'),
        content: const Text(
          'This will permanently delete every flock, record, '
          'expense and sale.\n\nThis cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Everything', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().clearAllData();
      final flockProvider = context.read<FlockProvider>();
      await flockProvider.clearPersistedSelectionForCurrentUser();
      flockProvider.reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ─── Account Actions ──────────────────────────────────────────────────────

  Future<void> _attemptSignIn(BuildContext context) async {
    final db = DatabaseService();
    final sync = context.read<SyncService>();

    final hasBusinessData = await db.hasAnyBusinessRecords();
    final hasPendingSync = sync.pendingCount > 0;

    if (!hasBusinessData && !hasPendingSync) {
      await _startSignInFlow(context);
      return;
    }

    String message = 'This device already contains Poultry Pro data.\n\n'
        'Signing in to another account will replace the data stored on '
        'this device with the selected account\'s cloud data.\n\n'
        'Any local data that has not been backed up will be permanently lost.\n\n'
        'Continue?';
    String title = 'Switch Account?';

    if (hasPendingSync) {
      message = 'You have local changes that have not yet been backed up.\n\n'
          'Signing in now will permanently delete those unsynced changes.\n\n'
          'Continue?';
      title = 'Unsaved Changes';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _startSignInFlow(context);
    }
  }

  Future<void> _startSignInFlow(BuildContext context) async {
    final sync = context.read<SyncService>();
    final license = context.read<LicenseProvider>();
    final auth = context.read<AuthProvider>();
    final flockProvider = context.read<FlockProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final recordProvider = context.read<DailyRecordProvider>();

    try {
      sync.stopPeriodicSync();

      while (sync.isSyncing) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await sync.syncNow();

      await DatabaseService().clearAllData();
      await DatabaseService().clearSyncQueue();
      await license.clearEntitlement();

      await flockProvider.clearPersistedSelectionForCurrentUser();

      await auth.signOut();

      final signedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );

      if (signedIn == true && context.mounted) {
        await license.loadEntitlement();
        sync.startPeriodicSync();
        unawaited(sync.downloadCloudData());

        await flockProvider.loadFlocks();
        if (context.mounted) await financeProvider.loadFarmFinanceData();
        if (context.mounted) {
          final flocks = flockProvider.flocks;
          if (flocks.isNotEmpty) {
            final ids = flocks.map((f) => f.id).toList();
            await recordProvider.loadLatestRecords(ids);
            await recordProvider.loadMortalityTotals(ids);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showSignOutDialog(
      BuildContext context, AuthProvider auth, String? email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You\'re signing out of:'),
            const SizedBox(height: AppTheme.spacingXS),
            Text(email ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppTheme.spacingMD),
            const Text('Your poultry records will remain on this device.'),
            const SizedBox(height: AppTheme.spacingXS),
            const Text('Cloud sync will stop.'),
            const SizedBox(height: AppTheme.spacingXS),
            const Text(
              'Another person using this phone can still view these records until they are erased.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final flockProvider = context.read<FlockProvider>();
      await flockProvider.clearPersistedSelectionForCurrentUser();
      await auth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out. A new anonymous session has been created.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showEraseDataDialog(BuildContext context) async {
    final sync = context.read<SyncService>();
    final pendingCount = sync.pendingCount;

    if (pendingCount > 0) {
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text(
            'You have $pendingCount records that haven\'t synced yet.\n\n'
            'Erasing now will permanently delete them.\n\n'
            'Connect to the internet first if you want to keep them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _doEraseData(context);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
              child: const Text('Erase Anyway'),
            ),
          ],
        ),
      );
    } else {
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erase All Data?'),
          content: const Text(
            'This will permanently delete all your poultry records, flocks, '
            'expenses, and sales from this device.\n\n'
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context, true);
                await _doEraseData(context);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
              child: const Text('Erase Everything'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _doEraseData(BuildContext context) async {
    final sync = context.read<SyncService>();
    final license = context.read<LicenseProvider>();
    final auth = context.read<AuthProvider>();

    try {
      sync.stopPeriodicSync();

      while (sync.isSyncing) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await sync.syncNow();

      await DatabaseService().clearAllData();
      await DatabaseService().clearSyncQueue();
      await license.clearEntitlement();

      final flockProvider = context.read<FlockProvider>();
      await flockProvider.clearPersistedSelectionForCurrentUser();
      flockProvider.reset();

      await auth.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data erased. New anonymous session created.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erase failed: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ─── Account & Cloud Configuration ─────────────────────────────────────────

  Widget _buildAccountAndCloudCard(BuildContext context, AuthProvider auth) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    final isProtected = auth.isVerified;
    final license = context.watch<LicenseProvider>();
    final entitlement = license.entitlement;
    final isPro = entitlement?.isPro ?? false;
    final expiry = entitlement?.expiresAt;
    final sync = context.watch<SyncService>();
    final pendingCount = sync.pendingCount;
    final lastSynced = sync.lastSyncedAt != null
        ? '${sync.lastSyncedAt!.day}/${sync.lastSyncedAt!.month}/${sync.lastSyncedAt!.year} '
          '${sync.lastSyncedAt!.hour}:${sync.lastSyncedAt!.minute.toString().padLeft(2, '0')}'
        : 'Never';

    return _SettingsSection(
      icon: Icons.shield_outlined,
      title: 'Account & Cloud',
      description: 'Manage your account, cloud backup and subscription.',
      color: AppTheme.primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: 'Signed in as',
            value: email ?? 'Anonymous',
            valueColor: email != null ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingMD),

          _InfoRow(
            label: 'Account Status',
            valueWidget: _buildStatusChip(
              isProtected ? 'Protected' : 'Not Protected',
              isProtected ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),

          _InfoRow(
            label: 'Plan',
            valueWidget: _buildStatusChip(
              isPro ? 'Premium' : 'Free',
              isPro ? Colors.green : Colors.grey,
            ),
            trailing: (isPro && expiry != null)
                ? Text(
                    'Valid until ${_formatExpiry(expiry)}',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  )
                : null,
          ),
          const SizedBox(height: AppTheme.spacingMD),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
            child: Divider(color: AppTheme.textSecondary.withOpacity(0.2), height: 1),
          ),
          const SizedBox(height: AppTheme.spacingSM),

          // Cloud Backup
          if (auth.isAnonymous) ...[
            _InfoRow(
              label: 'Cloud Backup',
              valueWidget: _buildStatusChip('Not Available', Colors.grey),
            ),
          ] else ...[
            _InfoRow(
              label: 'Cloud Backup',
              valueWidget: _buildStatusChip('Enabled', Colors.green),
            ),
            if (isPro) ...[
              const SizedBox(height: AppTheme.spacingXS),
              _InfoRow(
                label: 'Last sync',
                value: lastSynced,
                secondaryValue: pendingCount == 0
                    ? 'All changes backed up'
                    : '$pendingCount change${pendingCount == 1 ? '' : 's'} pending',
                secondaryValueColor:
                    pendingCount > 0 ? Colors.orange : AppTheme.textSecondary,
                trailing: _buildSyncButton(context, sync),
              ),
            ] else ...[
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Cloud backup protects your poultry records.',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ],

          const SizedBox(height: AppTheme.spacingLG),

          // Action buttons
          if (auth.isAnonymous) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupScreen()),
                    ),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('Protect My Backup'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                OutlinedButton(
                  onPressed: () => _attemptSignIn(context),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _attemptSignIn(context),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Switch Account'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSignOutDialog(context, auth, email),
                    icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.errorColor),
                    label: const Text('Sign Out', style: TextStyle(color: AppTheme.errorColor)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helper: Status Chip ──────────────────────────────────────────────────

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('🐔 PoultryPro Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // ── Account & Cloud ──────────────────────────────────────
          _buildAccountAndCloudCard(context, auth),
          const SizedBox(height: AppTheme.spacingLG),

          // ── Data Management ──────────────────────────────────────
          _SettingsSection(
            icon: Icons.storage_rounded,
            title: 'Data Management',
            description: 'Create and restore backups.',
            color: Colors.blue,
            child: Column(
              children: [
                _SettingsButton(
                  icon: Icons.backup_rounded,
                  title: 'Manual Backup',
                  subtitle: 'Save a local copy and share via WhatsApp',
                  color: AppTheme.secondaryColor,
                  onTap: () => _backupData(context),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                _SettingsButton(
                  icon: Icons.restore_page_rounded,
                  title: 'Restore From Backup',
                  subtitle: 'Load data from a previous backup file',
                  color: Colors.orange,
                  onTap: () => _restoreData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),

          // ── Danger Zone ──────────────────────────────────────────
          _SettingsSection(
            icon: Icons.warning_amber_rounded,
            title: 'Danger Zone',
            description: 'Permanent actions.',
            color: AppTheme.errorColor,
            child: Column(
              children: [
                _SettingsButton(
                  icon: Icons.delete_forever_rounded,
                  title: 'Clear All Data',
                  subtitle: 'Delete everything on this device — cannot be undone',
                  color: AppTheme.errorColor,
                  onTap: () => _clearAllData(context),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                _SettingsButton(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Erase Data & Sign Out',
                  subtitle: 'Permanently delete all local data and start fresh',
                  color: AppTheme.errorColor,
                  onTap: () => _showEraseDataDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),

          // ── Footer ───────────────────────────────────────────────
          const Center(
            child: Column(
              children: [
                _AppVersionText(),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Built for African Poultry Farmers',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
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

// ============================================================================
//   Reusable Info Row
// ============================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? secondaryValue;
  final Color? valueColor;
  final Color? secondaryValueColor;
  final Widget? trailing;
  final bool bold;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.secondaryValue,
    this.valueColor,
    this.secondaryValueColor,
    this.trailing,
    this.bold = false,
  }) : assert(value != null || valueWidget != null, 'Either value or valueWidget must be provided');

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              if (valueWidget != null)
                valueWidget!
              else if (value != null)
                Text(
                  value!,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                    color: valueColor ?? AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (secondaryValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  secondaryValue!,
                  style: AppTheme.bodySmall.copyWith(color: secondaryValueColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ============================================================================
//   Reusable Settings Button
// ============================================================================

class _SettingsButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSM,
          vertical: AppTheme.spacingSM,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//   Footer: App Version
// ============================================================================

class _AppVersionText extends StatefulWidget {
  const _AppVersionText();

  @override
  State<_AppVersionText> createState() => _AppVersionTextState();
}

class _AppVersionTextState extends State<_AppVersionText> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // leave blank
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'PoultryPro',
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Version $_version',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}