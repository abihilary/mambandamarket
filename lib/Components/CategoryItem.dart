import 'package:flutter/material.dart';

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
    return SizedBox(
      height: 95,
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
              width: 70, // Fixed width for uniform slider items
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cat.isSelected
                          ? Colors.indigo.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: cat.isSelected
                          ? Border.all(color: Colors.indigo, width: 2.0)
                          : Border.all(color: Colors.transparent),
                      boxShadow: cat.isSelected
                          ? [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ]
                          : [],
                    ),
                    child: Icon(
                      cat.icon,
                      size: 24,
                      color: cat.isSelected ? Colors.indigo : Colors.black87,
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
                      fontWeight: cat.isSelected ? FontWeight.bold : FontWeight.w500,
                      color: cat.isSelected ? Colors.indigo : Colors.black87,
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