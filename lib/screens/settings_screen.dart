import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'upgrade_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          SnackBar(
              content: Text('Sync failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
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
            content: Text(
                '✅ Backup saved! Send this file to yourself on WhatsApp.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Backup failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

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
              child: const Text('Yes, Restore',
                  style: TextStyle(color: Colors.red)),
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
          SnackBar(
              content: Text('Restore failed: $e'),
              backgroundColor: Colors.red),
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
            child: const Text('Delete Everything',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All data cleared'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Replacement bottom sheet for phone number entry
  void _showPhoneSignInSheet(BuildContext context) {
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your phone number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'We\'ll send a verification code to confirm your account.'),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+2348012345678',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final phone = phoneController.text.trim();
                  if (phone.isEmpty) return;
                  Navigator.pop(context);
                  final auth = context.read<AuthProvider>();
                  final sent = await auth.sendOtp(phone);
                  if (sent && context.mounted) {
                    _showOtpSheet(context, phone);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(auth.error ?? 'Failed to send code'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                child: const Text('Send Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtpSheet(BuildContext context, String phone) {
    final otpController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter verification code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Code sent to $phone'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: '123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final token = otpController.text.trim();
                  if (token.length != 6) return;
                  Navigator.pop(context);
                  final auth = context.read<AuthProvider>();
                  final verified = await auth.verifyOtp(token);
                  if (verified && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '✅ Account verified! You can now upgrade.'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(auth.error ?? 'Incorrect code'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                child: const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated sign-in prompt – uses phone bottom sheet instead of broken route
  void _showSignInRequired(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Sign In to Upgrade',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'You need a verified account to subscribe to Poultry Pro. '
              'Sign in with your phone number to continue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
                icon: const Icon(Icons.phone),
                label: const Text('Sign In with Phone'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProCard(BuildContext context, AuthProvider auth) {
    final isPro = context.watch<LicenseProvider>().isPro;
    final isAnonymous = auth.isAnonymous;

    return Card(
      color: isPro ? Colors.orange.shade50 : Colors.green.shade50,
      child: ListTile(
        leading: Icon(
          isPro ? Icons.stars : Icons.verified,
          color: isPro ? Colors.orange : Colors.green,
        ),
        title: Text(isPro ? 'PoultryPro Premium' : 'PoultryPro Plus'),
        subtitle: Text(
          isPro
              ? 'Subscription Active'
              : isAnonymous
                  ? 'Sign in to unlock Pro features'
                  : 'Manage your subscription',
        ),
        trailing: isPro
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: () async {

                  final user = Supabase.instance.client.auth.currentUser;

             if (user != null && user.isAnonymous) {
   Navigator.push(
     context,
     MaterialPageRoute(builder: (_) => const BackupScreen()),
   );
   return;
 }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UpgradeScreen(),
                    ),
                  );

                },
                child: Text(isAnonymous ? 'Sign In' : 'Upgrade'),
              ),
      ),
    );
  }

  Widget _buildCloudSyncCard(BuildContext context) {
    final isPro = context.watch<LicenseProvider>().isPro;
    final sync = context.watch<SyncService>();

    if (!isPro) {
      return Card(
        color: Colors.grey.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.1),
            child: Icon(Icons.cloud_off_outlined,
                color: AppTheme.textSecondary, size: 20),
          ),
          title: Text(
            'Cloud Sync',
            style: AppTheme.bodyLarge
                .copyWith(fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          subtitle: const Text(
            'Upgrade to Pro for automatic cloud backup',
            style: TextStyle(color: Colors.grey),
          ),
          trailing: Icon(Icons.lock_outline, color: Colors.grey, size: 20),
        ),
      );
    }

    final lastSynced = sync.lastSyncedAt != null
        ? '${sync.lastSyncedAt!.day}/${sync.lastSyncedAt!.month}/${sync.lastSyncedAt!.year} '
          '${sync.lastSyncedAt!.hour}:${sync.lastSyncedAt!.minute.toString().padLeft(2, '0')}'
        : 'Never';
    final pendingCount = sync.pendingCount;

    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_done_outlined,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: AppTheme.spacingSM),
                Text('Cloud Sync', style: AppTheme.headingSmall),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last synced: $lastSynced',
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingCount == 0
                          ? 'All changes backed up'
                          : '$pendingCount change${pendingCount == 1 ? '' : 's'} pending',
                      style: AppTheme.bodySmall.copyWith(
                        color: pendingCount > 0
                            ? AppTheme.warningColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _syncNow(context),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // ── Subscription Section ──────────────────────────
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text('Subscription', style: AppTheme.headingSmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),
                _buildProCard(context, auth),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),

          // ── Cloud Sync Section ────────────────────────────
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_done_outlined,
                        color: AppTheme.secondaryColor, size: 18),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text('Cloud Sync', style: AppTheme.headingSmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),
                _buildCloudSyncCard(context),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),

          // ── Data Management Section ───────────────────────
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_rounded,
                        color: AppTheme.secondaryColor, size: 18),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text('Data Management', style: AppTheme.headingSmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  'Cloud backup runs automatically. Use manual backup '
                  'to save a local copy to your phone.',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                _SettingsButton(
                  icon: Icons.backup,
                  title: 'Manual Backup',
                  subtitle: 'Save a local copy and share via WhatsApp',
                  color: AppTheme.secondaryColor,
                  onTap: () => _backupData(context),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                _SettingsButton(
                  icon: Icons.restore,
                  title: 'Restore From Backup',
                  subtitle: 'Load data from a previous backup file',
                  color: AppTheme.warningColor,
                  onTap: () => _restoreData(context),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                _SettingsButton(
                  icon: Icons.delete_forever,
                  title: 'Clear All Data',
                  subtitle: 'Delete everything — cannot be undone',
                  color: AppTheme.errorColor,
                  onTap: () => _clearAllData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),

          // ── Footer ────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text('App Version 1.0.2',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text('Built for African Poultry Farmers',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: AppTheme.bodyLarge
                .copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTheme.bodySmall),
        onTap: onTap,
        trailing: Icon(Icons.arrow_forward_ios,
            size: 16, color: AppTheme.textSecondary),
      ),
    );
  }
}
