import 'package:flutter/material.dart';
import 'package:my_home_ci/config/theme.dart';

class QuarterInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;

  const QuarterInfoCard({
    super.key,
    required this.icon,
    required this.label,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
          if (count != null) ...[
            const SizedBox(height: 2),
            Text(
              count!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
