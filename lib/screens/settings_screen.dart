import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

      // Write the file before sharing
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          Text('Data Management',
              style:
                  AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Cloud backup runs automatically. Use manual backup '
            'to save a local copy to your phone.',
            style: AppTheme.bodySmall
                .copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLG),
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
          const SizedBox(height: AppTheme.spacingXL),
          const Divider(),
          const SizedBox(height: AppTheme.spacingMD),
          Text('App Version 1.0.0',
              style:
                  AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
          Text('Built for Nigerian Poultry Farmers',
              style:
                  AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
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
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSecondary),
      ),
    );
  }
}