import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class CategoryItem {
  final String label;
  final IconData icon;
  final bool isSelected;

  CategoryItem({
    required this.label,
    required this.icon,
    this.isSelected = false,
  });
}

class CategoryBar extends StatelessWidget {
  final List<CategoryItem> categories;
  final Function(int)? onSelectCategory;

  const CategoryBar({
    Key? key,
    required this.categories,
    this.onSelectCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return SizedBox(
      height: 97,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // Smooth mobile scroll physics
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return GestureDetector(
            onTap: () => onSelectCategory?.call(index),
            child: SizedBox(
              // French labels run longer than the German originals
              // ("Électronique" vs "Elektronik"), so allow a little more room.
              width: 82,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Selected is a solid lime pill with a near-black glyph,
                  // as the deck draws it — not a tinted wash behind a lime
                  // icon. A fill reads as "chosen" at a glance where a 14%
                  // tint does not, and it works on either ground because what
                  // sits on lime is always near-black.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64,
                    height: 54,
                    decoration: BoxDecoration(
                      color: cat.isSelected
                          ? tokens.accentFill
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      cat.icon,
                      size: 24,
                      color: cat.isSelected
                          ? tokens.onAccentFill
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight:
                          cat.isSelected ? FontWeight.bold : FontWeight.w500,
                      // accentInk, not the fill: the label sits on the page,
                      // not on the pill, so it needs the readable variant.
                      color: cat.isSelected
                          ? tokens.accentInk
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}