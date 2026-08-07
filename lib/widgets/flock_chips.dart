import 'package:flutter/material.dart';

import '../models/flock.dart';
import '../theme/app_theme.dart';

/// Small uppercase pill for a flock's lifecycle status.
///
/// `active` → success green; any other status (sold, archived, …) → warning
/// amber. Replaces the three inline copies that lived in [FlockHeader], the
/// HomeScreen grid card, and the FlocksScreen grid card.
class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  final Color? color;
  final double fontSize;

  const StatusBadge(
    this.status, {
    super.key,
    this.label,
    this.color,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    final resolvedColor =
        color ?? (isActive ? AppTheme.successColor : AppTheme.warningColor);
    final text = (label ?? status).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

/// Tinted pill showing a flock's production stage (Brooding, Laying, …),
/// coloured via the centralised [AppTheme.stageColor] so it matches the stage
/// colour used everywhere else.
class StageChip extends StatelessWidget {
  final String stage;
  final double fontSize;

  const StageChip(
    this.stage, {
    super.key,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stage,
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Tinted pill summarising the next upcoming vaccination for a flock.
///
/// ≤ 3 days away → error red; otherwise → warning amber. Returns
/// [SizedBox.shrink] when there is no upcoming vaccination.
class VaccinationChip extends StatelessWidget {
  final Flock flock;
  final double fontSize;

  const VaccinationChip(
    this.flock, {
    super.key,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final next = flock.nextVaccination;
    if (next == null) return const SizedBox.shrink();

    final daysToNext = next.daysUntil(flock.currentAgeDays);
    final urgent = daysToNext <= 3;
    final color = urgent ? AppTheme.errorColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Next vax: ${next.name} ($daysToNext day${daysToNext == 1 ? '' : 's'})',
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
