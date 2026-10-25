import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/listing_attributes.dart';
import '../api/listing_guide.dart';
import '../api/listing_presentation.dart';
import '../api/models.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';
import 'VerifiedBadge.dart';
import 'rating_badge.dart';

// The item page's blocks, built from what the seller answered (§6.7 of the
// category-native listings spec). Each one follows the same rule as
// listing_presentation.dart: nothing is drawn that the data cannot back, so a
// block with nothing true to say draws nothing at all.

/// The item page's fact chips: the card fields and the condition
/// ("Comme neuf", "Batt. 88 %"), then "Garantie vendeur" when it means
/// anything here. At most four.
List<String> keyFacts(
  Listing x,
  List<AttrField> fields,
  ListingGuide g,
  AppLocalizations l10n,
  Locale l,
) => [
  ...specParts(x, fields, g, l10n, l, forCard: false),
  if (x.hasGuarantee && g.warranty) l10n.detailWarranty,
].take(4).toList();

/// The card at the top of the item page: where, what, how much, and the
/// handful of facts a buyer decides on before reading anything else.
///
/// Strings rather than a listing, because the page draws this from the feed's
/// title and price before the full listing has loaded.
class KeyFactsCard extends StatelessWidget {
  final String title;
  final ({String main, String? tail, bool negotiableChip}) price;

  /// The guide's name for the price ("Loyer"), as a small overline.
  final String? priceLabel;
  final String? city;
  final VoidCallback? onCityTap;
  final List<String> facts;

  /// Null hides the delivery row: no shipping, or a category it means nothing
  /// for (a flat, a job).
  final VoidCallback? onDeliveryTap;
  final String? categoryLabel;
  final VoidCallback? onCategoryTap;
  final String? posted;

  /// Already worded ("175 vues"); null when the count is too small to mean
  /// anything.
  final String? views;

  /// The buttons, on a wide screen where the card is the sticky column.
  final Widget? actions;

  /// The phone layout draws this card's top edge over the gallery (see
  /// [KeyFactsCap]); the card itself then starts square, with no top border.
  final bool attachedTop;

  const KeyFactsCard({
    super.key,
    required this.title,
    required this.price,
    this.priceLabel,
    this.city,
    this.onCityTap,
    this.facts = const [],
    this.onDeliveryTap,
    this.categoryLabel,
    this.onCategoryTap,
    this.posted,
    this.views,
    this.actions,
    this.attachedTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ink = context.tokens.accentInk;
    final line = BorderSide(color: Theme.of(context).dividerColor);
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final place = city?.trim() ?? '';
    final meta = [
      if (posted != null && posted!.isNotEmpty) posted!,
      ?views,
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, attachedTop ? 0 : 16, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: attachedTop
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.circular(16),
        border: attachedTop
            ? Border(left: line, right: line, bottom: line)
            : Border.fromBorderSide(line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place.isNotEmpty) ...[
            Tappable(
              onTap: onCityTap,
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: ink),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                  if (onCityTap != null)
                    Icon(Icons.chevron_right, size: 16, color: ink),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, height: 1.25),
          ),
          const SizedBox(height: 10),
          if (priceLabel != null) Text(priceLabel!, style: muted),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                price.main,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  // accentInk, as on the cards: one price colour everywhere.
                  color: ink,
                ),
              ),
              if (price.tail != null)
                Text(price.tail!,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              if (price.negotiableChip)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.onSurfaceVariant),
                  ),
                  child: Text(
                    l10n.detailNegotiableChip,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final f in facts) _FactChip(f)],
            ),
          ],
          if (onDeliveryTap != null) ...[
            const SizedBox(height: 10),
            // Says what is true — Mambanda quotes a delivery — and nothing
            // about price, speed or paying on arrival.
            InkWell(
              onTap: onDeliveryTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.detailDeliveryQuote,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
          if (categoryLabel != null || meta.isNotEmpty) ...[
            Divider(height: 24, color: line.color),
            Row(
              children: [
                if (categoryLabel != null)
                  Flexible(
                    child: Semantics(
                      button: onCategoryTap != null,
                      label: '${l10n.detailCategory}: $categoryLabel',
                      excludeSemantics: true,
                      child: Tappable(
                        onTap: onCategoryTap,
                        child: Text(
                          categoryLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                if (meta.isNotEmpty)
                  Flexible(
                    child: Text(
                      categoryLabel != null ? ' · $meta' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ),
              ],
            ),
          ],
          if (actions != null) ...[
            const SizedBox(height: 16),
            actions!,
          ],
        ],
      ),
    );
  }
}

/// The top 16px of an attached [KeyFactsCard], drawn at the foot of the
/// phone gallery.
///
/// The card cannot simply be shifted up over the photo: the gallery is a
/// pinned SliverAppBar, which paints over everything after it, so a
/// translated card would vanish under the picture. This piece lives inside
/// the app bar instead and fades as the bar collapses, by which time the card
/// itself is sliding under the toolbar.
class KeyFactsCap extends StatelessWidget {
  final double opacity;
  const KeyFactsCap({super.key, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: Theme.of(context).dividerColor);
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: line, left: line, right: line),
          ),
        ),
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  final String text;
  const _FactChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

// ── Details ─────────────────────────────────────────────────────────────────

/// One line of the details table. A null [label] is a fact that reads as a
/// sentence on its own ("En stock : 3").
class DetailRow {
  final String? label;
  final String value;

  /// The template's sub-head over this row ("Papiers"), if any.
  final String? section;

  const DetailRow({this.label, required this.value, this.section});
}

/// A checklist field's ticked options, under its own label.
class DetailChecklist {
  final String label;
  final List<String> items;
  final String? section;

  const DetailChecklist({
    required this.label,
    required this.items,
    this.section,
  });
}

/// Everything the details block shows for a listing, computed once per build
/// — the page also needs the row count to decide whether an empty
/// description is worth a line.
class ListingDetails {
  final List<DetailRow> rows;

  /// Labels of the bools answered true ("Déconnecté d'iCloud / Google").
  final List<String> highlights;
  final List<DetailChecklist> checklists;

  const ListingDetails({
    this.rows = const [],
    this.highlights = const [],
    this.checklists = const [],
  });

  static const empty = ListingDetails();

  bool get isEmpty => rows.isEmpty && highlights.isEmpty && checklists.isEmpty;

  /// In display order: the condition, the answered fields, the warranty and
  /// the stock; true bools as highlights; checklists as blocks. A false bool,
  /// an empty answer and a condition never chosen are simply not there.
  factory ListingDetails.of(
    Listing x,
    List<AttrField> fields,
    ListingGuide g,
    AppLocalizations l10n,
    Locale l,
  ) {
    final rows = <DetailRow>[];
    final highlights = <String>[];
    final checklists = <DetailChecklist>[];
    if (x.isProduct && g.condition) {
      final condition = conditionLabel(l10n, x.condition);
      if (condition != null) {
        rows.add(DetailRow(label: l10n.createCondition, value: condition));
      }
    }
    for (final f in displayFields(fields)) {
      final value = x.attributes[f.key];
      if (f.isChecklist) {
        final items = _ticked(f, value, l);
        if (items.isNotEmpty) {
          checklists.add(DetailChecklist(
              label: f.label(l), items: items, section: f.section(l)));
        }
      } else if (f.type == 'bool') {
        if (value == true) highlights.add(f.label(l));
      } else if (f.format(value, l, yes: l10n.detailsYes) case final String s) {
        rows.add(DetailRow(label: f.label(l), value: s, section: f.section(l)));
      }
    }
    if (x.hasGuarantee && g.warranty) {
      rows.add(DetailRow(label: l10n.detailWarranty, value: l10n.detailsYes));
    }
    if (x.isProduct && x.quantity > 1) {
      rows.add(DetailRow(value: l10n.detailInStock(x.quantity)));
    }
    return ListingDetails(
        rows: rows, highlights: highlights, checklists: checklists);
  }

  /// A checklist's answers in template order, then any value the template
  /// has since dropped.
  static List<String> _ticked(AttrField f, dynamic value, Locale l) {
    if (!AttrField.answered(value)) return const [];
    final picked = {
      for (final v in (value is List ? value : [value]))
        if (v != null) v.toString(),
    };
    final known = {for (final o in f.options) o.value};
    return [
      for (final o in f.options)
        if (picked.contains(o.value)) o.label(l),
      for (final v in picked)
        if (!known.contains(v)) v,
    ];
  }
}

/// The details block: rows, sub-heads, highlights, checklists and the
/// "provided by the seller" line. Nothing at all when there is nothing to
/// list — the heading used to print over an empty space on every listing.
class DetailsTable extends StatefulWidget {
  final ListingDetails details;

  /// 2 lays the rows out as a two-column grid, for a wide window.
  final int columns;

  const DetailsTable({super.key, required this.details, this.columns = 1});

  /// More rows than this fold, leaving [_folded] showing.
  static const _foldAbove = 8;
  static const _folded = 6;

  @override
  State<DetailsTable> createState() => _DetailsTableState();
}

class _DetailsTableState extends State<DetailsTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    if (d.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ink = context.tokens.accentInk;
    final folds = d.rows.length > DetailsTable._foldAbove;
    final rows = folds && !_expanded
        ? d.rows.take(DetailsTable._folded).toList()
        : d.rows;

    final children = <Widget>[
      Text(l10n.detailDetails,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
    ];

    // Rows in runs that share a section, each run under its sub-head.
    String? section;
    var run = <DetailRow>[];
    void flush() {
      if (run.isNotEmpty) children.add(_grid(context, run));
      run = [];
    }

    for (final r in rows) {
      if (r.section != section) {
        flush();
        section = r.section;
        if (section != null) children.add(_SubHead(section));
      }
      run.add(r);
    }
    flush();

    if (folds) {
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(
            foregroundColor: ink,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          iconAlignment: IconAlignment.end,
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
              size: 18),
          label: Text(_expanded
              ? l10n.detailShowFewerDetails
              : l10n.detailShowAllDetails(d.rows.length)),
        ),
      ));
    }

    if (d.highlights.isNotEmpty) {
      children
        ..add(_SubHead(l10n.detailHighlights))
        ..add(Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [for (final h in d.highlights) _Tick(h, ink: ink)],
        ));
    }

    String? checklistSection;
    for (final c in d.checklists) {
      if (c.section != null && c.section != checklistSection) {
        children.add(_SubHead(c.section!, strong: true));
      }
      checklistSection = c.section;
      children
        ..add(_SubHead(c.label))
        ..add(LayoutBuilder(builder: (context, box) {
          // Two to a row on a phone, more when there is room.
          final perRow = (box.maxWidth / 200).floor().clamp(2, 4);
          final w = (box.maxWidth - 12 * (perRow - 1)) / perRow;
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final item in c.items)
                SizedBox(width: w, child: _Tick(item, ink: ink, expand: true)),
            ],
          );
        }));
    }

    children
      ..add(const SizedBox(height: 12))
      ..add(Text(
        l10n.detailBySeller,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// [rows] one or two to a line, with a hairline between lines.
  Widget _grid(BuildContext context, List<DetailRow> rows) {
    final perLine = widget.columns >= 2 ? 2 : 1;
    final lines = <Widget>[];
    for (var i = 0; i < rows.length; i += perLine) {
      if (lines.isNotEmpty) {
        lines.add(Divider(height: 1, color: Theme.of(context).dividerColor));
      }
      lines.add(perLine == 1
          ? _Row(rows[i])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Row(rows[i])),
                const SizedBox(width: 24),
                Expanded(
                  child: i + 1 < rows.length
                      ? _Row(rows[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lines,
    );
  }
}

class _Row extends StatelessWidget {
  final DetailRow row;
  const _Row(this.row);

  @override
  Widget build(BuildContext context) {
    final value = Text(
      row.value,
      softWrap: true,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: row.label == null
          ? value
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 40 / 60, so the values line up down the table whatever the
                // labels say.
                Expanded(
                  flex: 4,
                  child: Text(
                    row.label!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: value),
              ],
            ),
    );
  }
}

class _SubHead extends StatelessWidget {
  final String text;

  /// A template section ("Équipements") over several checklists, a step
  /// louder than each checklist's own label.
  final bool strong;
  const _SubHead(this.text, {this.strong = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: strong ? 14 : 13,
        fontWeight: FontWeight.w700,
        color: strong ? null : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _Tick extends StatelessWidget {
  final String text;
  final Color ink;
  final bool expand;
  const _Tick(this.text, {required this.ink, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: const TextStyle(fontSize: 14));
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.check, size: 16, color: ink),
        ),
        const SizedBox(width: 6),
        if (expand) Expanded(child: label) else Flexible(child: label),
      ],
    );
  }
}

// ── Description ─────────────────────────────────────────────────────────────

/// The seller's own words, under a heading, folded after [maxLines] when they
/// run long. Short text is shown whole, with no "Show more" that reveals
/// nothing.
class CollapsibleDescription extends StatefulWidget {
  final String? text;

  /// 5 on a phone, 8 beside a wide gallery.
  final int maxLines;

  /// An empty description says nothing at all when the details already say
  /// plenty (four rows or more); otherwise it says so in one muted line.
  final bool hideWhenEmpty;

  const CollapsibleDescription({
    super.key,
    required this.text,
    this.maxLines = 5,
    this.hideWhenEmpty = false,
  });

  @override
  State<CollapsibleDescription> createState() => _CollapsibleDescriptionState();
}

class _CollapsibleDescriptionState extends State<CollapsibleDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = widget.text?.trim() ?? '';
    if (text.isEmpty && widget.hideWhenEmpty) return const SizedBox.shrink();

    final heading = Text(l10n.detailDescription,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
    if (text.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 8),
          Text(l10n.detailNoDescriptionYet,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
        ],
      );
    }

    final style = TextStyle(height: 1.5, color: scheme.onSurface, fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          // Measured at the width it will be drawn at, with the same style
          // and text size, so the fold appears exactly when the text is
          // longer than the fold.
          final painter = TextPainter(
            text: TextSpan(
                text: text,
                style: DefaultTextStyle.of(context).style.merge(style)),
            maxLines: widget.maxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: box.maxWidth);
          final overflows = painter.didExceedMaxLines;
          painter.dispose();

          if (!overflows) return Text(text, style: style);
          final folded = !_expanded;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (folded)
                ShaderMask(
                  // The last 24px fade out, so the cut reads as "more below"
                  // rather than as a line that was lost.
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Colors.black, Colors.black, Colors.transparent],
                    stops: [
                      0,
                      rect.height <= 24 ? 0 : (rect.height - 24) / rect.height,
                      1,
                    ],
                  ).createShader(rect),
                  child: Text(
                    text,
                    style: style,
                    maxLines: widget.maxLines,
                    overflow: TextOverflow.clip,
                  ),
                )
              else
                Text(text, style: style),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: context.tokens.accentInk,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(folded ? l10n.detailShowMore : l10n.detailShowLess),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ── Seller ──────────────────────────────────────────────────────────────────

/// Who is selling, in facts rather than adjectives: what kind of seller, how
/// many listings, how long on Mambanda, and a rating only once three reviews
/// stand behind it.
class SellerCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback? onTap;

  /// For tests; the clock otherwise.
  final DateTime? now;

  const SellerCard({super.key, required this.listing, this.onTap, this.now});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final x = listing;
    final name = (x.sellerLabel?.trim().isNotEmpty ?? false)
        ? x.sellerLabel!
        : l10n.profileFallbackName;
    final image = x.sellerImageUrl;
    final hasImage = image != null && image.trim().isNotEmpty;
    final kind = x.sellerRole == 'company'
        ? l10n.sellerBusinessVerified
        : x.storeId != null && x.storeVerified
        ? l10n.sellerShopVerified
        : x.storeId != null
        ? l10n.sellerShop
        : l10n.sellerPrivate;
    final city = x.sellerCity?.trim() ?? '';
    final chips = SellerChips(
      listings: x.sellerActiveListings,
      memberSince: x.sellerCreatedAt,
      ratingAvg: x.storeRatingAvg,
      ratingCount: x.storeRatingCount,
      now: now,
    );

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    backgroundImage:
                        hasImage ? CachedNetworkImageProvider(image) : null,
                    child: hasImage
                        ? null
                        : Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: scheme.primary),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (x.sellerVerified) ...[
                                    const SizedBox(width: 5),
                                    const VerifiedBadge(dense: true),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              x.storeId != null
                                  ? l10n.sellerViewShop
                                  : l10n.profileViewSeller,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.tokens.accentInk),
                            ),
                            Icon(Icons.chevron_right,
                                size: 19, color: context.tokens.accentInk),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          city.isEmpty ? kind : '$kind · $city',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 60, top: 10),
                child: chips,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A seller's stat chips: listings, membership, and the rating once it means
/// something. Shared by the item page's seller card and the seller's own page,
/// so the two never say different things about the same person.
class SellerChips extends StatelessWidget {
  /// Active listings. Null or 0 shows no chip — "0 annonces" beside a listing
  /// would be untrue, and null means the server did not count.
  final int? listings;
  final DateTime? memberSince;
  final double? ratingAvg;
  final int ratingCount;
  final DateTime? now;

  /// Fewer reviews than this is an anecdote, not a rating.
  static const minReviews = 3;

  const SellerChips({
    super.key,
    this.listings,
    this.memberSince,
    this.ratingAvg,
    this.ratingCount = 0,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final joined = memberSince;
    final avg = ratingAvg;
    final chips = <Widget>[
      if ((listings ?? 0) >= 1) _StatChip(l10n.sellerListings(listings!)),
      if (joined != null)
        _StatChip(
          (now ?? DateTime.now()).difference(joined).inDays >= 30
              ? l10n.sellerMemberSince(
                  DateFormat.yMMMM(locale).format(joined.toLocal()))
              : l10n.sellerNew,
        ),
      if (avg != null && ratingCount >= minReviews)
        _RatingChip(
          l10n.sellerReviews(NumberFormat('0.0', locale).format(avg), ratingCount),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _StatChip extends StatelessWidget {
  final String text;
  const _StatChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );
}

/// The rating in the same ink as [RatingBadge], worded with its count.
class _RatingChip extends StatelessWidget {
  final String text;
  const _RatingChip(this.text);

  @override
  Widget build(BuildContext context) {
    final ink = ratingInk(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: isDark ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: ink),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
        ],
      ),
    );
  }
}

// ── Before you pay ──────────────────────────────────────────────────────────

/// The category's buyer tips, one showing and the rest a tap away. Advice in
/// one quiet card at the end, rather than warnings between the facts.
class BuyerTipsCard extends StatefulWidget {
  final List<String> tips;
  const BuyerTipsCard({super.key, required this.tips});

  /// The tips for [x]: the guide's (at most three), else the general three
  /// for a product. A protected purchase leads with paying in the app, the
  /// one tip that is a promise rather than advice.
  static List<String> tipsFor(
    Listing x,
    ListingGuide g,
    AppLocalizations l10n,
    Locale l, {
    bool protected = false,
  }) {
    final tips = [for (final t in g.buyerTips.take(3)) t.text(l)];
    if (tips.isEmpty && x.isProduct) {
      tips.addAll([l10n.tipDefault1, l10n.tipDefault2, l10n.tipDefault3]);
    }
    return [if (protected) l10n.tipProtected, ...tips];
  }

  @override
  State<BuyerTipsCard> createState() => _BuyerTipsCardState();
}

class _BuyerTipsCardState extends State<BuyerTipsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tips = widget.tips;
    if (tips.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final shown = _expanded ? tips : tips.take(1);
    const style = TextStyle(fontSize: 13, height: 1.4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: context.tokens.groupSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(l10n.detailBuyerTipsTitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(t, style: style),
            ),
          if (tips.length > 1)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: context.tokens.accentInk,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              iconAlignment: IconAlignment.end,
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18),
              label: Text(_expanded
                  ? l10n.detailShowLess
                  : l10n.detailBuyerTipsMore(tips.length)),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
