import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/l10n.dart';
import 'category_icons.dart';

/// Ask the seller to pick a category, and return its slug.
///
/// Replaces a `DropdownButtonFormField`. That worked at twelve categories and
/// falls apart at eighty-eight: a dropdown is one scrolling column with no way
/// to search it, so filing a bag of rice meant reading past sixty unrelated
/// entries to find "Groceries".
///
/// Two ways in, because sellers arrive knowing different amounts:
///
///   * Drill down — the ten-or-so top-level groups, then what is inside one.
///     Good when you want to see what the marketplace actually has.
///   * Search — matches roots and leaves at once, showing each leaf under its
///     group so two similarly named ones can be told apart.
///
/// Returns null if the sheet is dismissed, which the caller must treat as "no
/// change" rather than "cleared".
Future<String?> showCategoryPicker(
  BuildContext context, {
  required List<Category> categories,
  String? selectedSlug,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CategoryPickerSheet(
      categories: categories,
      selectedSlug: selectedSlug,
    ),
  );
}

/// Lowercase and strip accents, so "electronique" finds "Électronique".
///
/// This market types in French on phone keyboards where the accented key is a
/// long-press away. Matching the raw string means the accented half of the
/// catalogue is unsearchable to anyone in a hurry.
String foldForSearch(String input) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i == -1 ? ch : to[i]);
  }
  return buffer.toString();
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<Category> categories;
  final String? selectedSlug;

  const _CategoryPickerSheet({required this.categories, this.selectedSlug});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final TextEditingController _search = TextEditingController();
  late final List<CategoryGroup> _groups = CategoryGroup.from(widget.categories);

  /// The group being browsed, or null at the top level.
  CategoryGroup? _openGroup;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Open on the group the current selection lives in, so re-opening the
    // picker to change a choice does not start from the top every time.
    final selected = widget.selectedSlug;
    if (selected != null) {
      for (final group in _groups) {
        if (group.children.any((c) => c.slug == selected)) {
          _openGroup = group;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Every category whose name matches the query, roots included.
  List<Category> get _matches {
    final q = foldForSearch(_query.trim());
    if (q.isEmpty) return const [];
    final locale = Localizations.localeOf(context);
    return widget.categories
        .where((c) => foldForSearch(c.displayLabel(locale)).contains(q))
        .toList();
  }

  String _labelOf(Category c) =>
      c.displayLabel(Localizations.localeOf(context));

  String? _parentLabelOf(Category c) {
    if (c.parentSlug == null) return null;
    for (final group in _groups) {
      if (group.root.slug == c.parentSlug) return _labelOf(group.root);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final searching = _query.trim().isNotEmpty;
    final group = _openGroup;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
            child: Row(
              children: [
                // Only inside a group, and only when not searching — search is
                // global, so backing out of it would be meaningless.
                if (group != null && !searching)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => setState(() => _openGroup = null),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group != null && !searching
                        ? _labelOf(group.root)
                        : l10n.categoryPickerTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.categoryPickerSearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: searching
                ? _buildSearchResults(scrollController)
                : group == null
                    ? _buildRoots(scrollController)
                    : _buildGroup(scrollController, group),
          ),
        ],
      ),
    );
  }

  Widget _buildRoots(ScrollController controller) => ListView.builder(
        controller: controller,
        itemCount: _groups.length,
        itemBuilder: (context, i) {
          final group = _groups[i];
          final hasChildren = group.children.isNotEmpty;
          return ListTile(
            leading: Icon(categoryIcon(group.root)),
            title: Text(_labelOf(group.root)),
            subtitle: hasChildren
                ? Text(context.l10n.categoryPickerCount(group.children.length))
                : null,
            trailing: hasChildren ? const Icon(Icons.chevron_right) : null,
            selected: widget.selectedSlug == group.root.slug,
            // A group with nothing under it is itself the answer; one with
            // children opens, and its own "all in" row is offered inside.
            onTap: () => hasChildren
                ? setState(() => _openGroup = group)
                : Navigator.pop(context, group.root.slug),
          );
        },
      );

  Widget _buildGroup(ScrollController controller, CategoryGroup group) {
    return ListView.builder(
      controller: controller,
      itemCount: group.children.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          // Filing on the root stays possible. Every listing published before
          // the tree existed sits on one, and some things genuinely do not
          // belong to any single leaf.
          return ListTile(
            leading: Icon(categoryIcon(group.root)),
            title: Text(
              context.l10n.categoryPickerAllIn(_labelOf(group.root)),
            ),
            selected: widget.selectedSlug == group.root.slug,
            onTap: () => Navigator.pop(context, group.root.slug),
          );
        }
        final child = group.children[i - 1];
        return ListTile(
          leading: Icon(categoryIcon(child)),
          title: Text(_labelOf(child)),
          selected: widget.selectedSlug == child.slug,
          onTap: () => Navigator.pop(context, child.slug),
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController controller) {
    final matches = _matches;
    if (matches.isEmpty) {
      return ListView(
        controller: controller,
        children: [
          const SizedBox(height: 48),
          Center(
            child: Text(
              context.l10n.categoryPickerNoMatch,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final c = matches[i];
        final parent = _parentLabelOf(c);
        return ListTile(
          leading: Icon(categoryIcon(c)),
          title: Text(_labelOf(c)),
          // "Shoes" and "Kids' clothing" both read as clothing; the group is
          // what tells them apart in a flat result list.
          subtitle: parent == null ? null : Text(parent),
          selected: widget.selectedSlug == c.slug,
          onTap: () => Navigator.pop(context, c.slug),
        );
      },
    );
  }
}
