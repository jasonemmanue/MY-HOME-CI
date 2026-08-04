import 'package:flutter/material.dart';
import 'package:my_home_ci/config/theme.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FilterChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: isSelected,
            onSelected: (_) => onSelected(index),
            selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
            backgroundColor: Theme.of(context).colorScheme.surface,
            labelStyle: TextStyle(
              color: isSelected
                  ? AppTheme.primaryGreen
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppTheme.primaryGreen
                  : Theme.of(context).dividerColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
