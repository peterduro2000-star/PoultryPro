import 'package:flutter/material.dart';
import '../models/daily_record.dart';
import '../models/flock.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'flock_chips.dart';
import 'stat_row.dart';

/// Single shared flock tile, used by both the Home dashboard and the
/// Flocks tab. These used to be two separately-maintained
/// `_FlockGridCard` classes that had drifted apart: the Flocks tab
/// version showed eggs/mortality/break-even/recovery/mortality-loss,
/// while the Home version (same class name, different file) showed only
/// name/bird-count/age — so the same flock looked like two different
/// things depending on which tab you were on.
///
/// [showDetailedStats] controls that difference explicitly now instead
/// of by accident: pass `false` on the Home dashboard (smaller cards,
/// less room) and `true` on the Flocks tab (full detail).
class FlockGridCard extends StatelessWidget {
  final Flock flock;
  final DailyRecord? latestRecord;
  final bool isSelected;
  final int mortalityTotal;
  final double breakEvenPerBird;
  final String breakEvenDisplay;
  final double recoveryPercentage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDetailedStats;

  const FlockGridCard({
    super.key,
    required this.flock,
    required this.latestRecord,
    required this.isSelected,
    required this.mortalityTotal,
    required this.breakEvenPerBird,
    required this.breakEvenDisplay,
    required this.recoveryPercentage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.showDetailedStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final nextVax = flock.nextVaccination;
    final daysToNext =
        nextVax != null ? nextVax.daysUntil(flock.currentAgeDays) : null;
    final costRecovered = recoveryPercentage >= 100;
    final mortalityBase = flock.initialBirdCount;
    final mortalityPercentage =
        mortalityBase > 0 ? mortalityTotal / mortalityBase * 100 : 0.0;
    final mortalityLoss = mortalityTotal * breakEvenPerBird;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: isSelected
              ? Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  width: 1.5,
                )
              : null,
          boxShadow: [isSelected ? AppTheme.shadowLG : AppTheme.shadowMD],
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    flock.name,
                    style: AppTheme.bodyLarge
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                StatusBadge(flock.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.groups, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${flock.birdCount} ${flock.type}',
                    style: AppTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 12, color: AppTheme.primaryColor),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    flock.ageDisplay,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.primaryColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            StageChip(flock.productionStage),
            if (daysToNext != null) ...[
              const SizedBox(height: 6),
              VaccinationChip(flock),
            ],
            if (showDetailedStats) ...[
              const Divider(height: AppTheme.spacingLG),
              if (latestRecord != null) ...[
                if (flock.isLayer) ...[
                  StatRow(
                    icon: Icons.egg,
                    label: 'Eggs today',
                    value: '${latestRecord!.eggsCollected ?? 0}',
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 4),
                ],
                StatRow(
                  icon: Icons.warning,
                  label: 'Mortality',
                  value: mortalityTotal > 0
                      ? '${mortalityPercentage.toStringAsFixed(1)}%'
                      : '0%',
                  color: mortalityTotal > 0
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
              ] else
                Text(
                  'No records yet',
                  style:
                      AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              const SizedBox(height: 4),
              StatRow(
                icon: costRecovered ? Icons.check_circle : Icons.price_check,
                label: costRecovered ? 'Cost recovered' : 'Break-even',
                value: costRecovered
                    ? '${recoveryPercentage.toStringAsFixed(0)}%'
                    : breakEvenDisplay,
                color: costRecovered
                    ? AppTheme.successColor
                    : AppTheme.accentColor,
              ),
              if (!costRecovered)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Recovered ${recoveryPercentage.toStringAsFixed(0)}%',
                    style: AppTheme.bodySmall.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (mortalityTotal > 0 && breakEvenPerBird > 0) ...[
                const SizedBox(height: 4),
                StatRow(
                  icon: Icons.money_off,
                  label: 'Mortality loss',
                  value: CurrencyFormatter.formatCompact(mortalityLoss),
                  color: AppTheme.errorColor,
                ),
              ],
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline,
                      size: 16, color: AppTheme.errorColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

