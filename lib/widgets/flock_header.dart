import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flock_provider.dart';
import '../theme/app_theme.dart';

class FlockHeader extends StatelessWidget {
  const FlockHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FlockProvider>(
      builder: (context, provider, _) {
        final flock = provider.selectedFlock;

        if (flock == null) {
          return Container(
            width: double.infinity,
            color: AppTheme.backgroundColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMD,
              vertical: AppTheme.spacingSM,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.spacingSM),
                Text('No flock selected — go to Home to select one',
                    style: AppTheme.bodySmall),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          color: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingSM,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Flock icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.egg_alt, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              // Flock name + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flock name — bold and prominent
                    Text(
                      flock.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Secondary info row
                    Row(
                      children: [
                        Text(
                          '${flock.birdCount} birds  •  ${flock.type}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status badge — small, at bottom
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: flock.status == 'active'
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            flock.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
