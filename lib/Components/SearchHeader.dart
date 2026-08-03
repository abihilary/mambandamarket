import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class SearchHeader extends StatefulWidget {
  final String locationText;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationTap;

  const SearchHeader({
    Key? key,
    // Callers pass the signed-in user's city; this is only the signed-out
    // fallback, so it must stay location-neutral.
    this.locationText = "toute la région",
    this.onSearchSubmitted,
    this.onSearchChanged,
    this.onLocationTap,
    this.onNotificationTap,
  }) : super(key: key);

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Search Input Container
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search,
                      color: scheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 8),

                  // Real TextField for typing input
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: widget.onSearchChanged,
                      onSubmitted: widget.onSearchSubmitted,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText:
                            context.l10n.searchHintRegion(widget.locationText),
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          overflow: TextOverflow.ellipsis,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Clear button when user types something
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                        });
                        widget.onSearchChanged?.call("");
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(Icons.close,
                            size: 18, color: scheme.onSurfaceVariant),
                      ),
                    ),

                  // Location Tag Button
                  GestureDetector(
                    onTap: widget.onLocationTap,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0, left: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: scheme.onPrimary,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell Button
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: Icon(
              Icons.notifications_none_outlined,
              color: scheme.onSurface,
              size: 26,
            ),
            onPressed: widget.onNotificationTap,
          ),
        ],
      ),
    );
  }
}