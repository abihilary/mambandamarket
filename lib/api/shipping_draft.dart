import 'models.dart';

/// Which path the form is on. Null until the customer has chosen one.
enum ShippingSource { mambanda, external }

/// A field the form still needs, in the order it appears on screen.
enum ShippingField {
  source,
  item,
  category,
  size,
  sizeCustom,
  from,
  to,
  phone,
}

/// Everything the shipping form knows, and whether it is ready to send.
///
/// A plain immutable value rather than a dozen controllers read inline, because
/// the rules branch three ways and every one of them is invisible in a widget:
///
///   * a description is required only when there is no link *and* no listing,
///   * a size code is required only when the category actually has presets,
///   * the whole item section does not exist on the Mambanda path.
///
/// [missing] drives both the submit button's enabled state and the scroll to
/// the first unfinished field, so those two can never disagree about whether
/// the form is done.
class ShippingDraft {
  const ShippingDraft({
    this.source,
    this.listing,
    this.productUrl = '',
    this.description = '',
    this.categorySlug = '',
    this.sizeCode = '',
    this.sizeCustom = '',
    this.fromLocation = '',
    this.toLocation = '',
    this.contactPhone = '',
    this.categoryHasPresets = false,
  });

  final ShippingSource? source;
  final Listing? listing;
  final String productUrl;
  final String description;
  final String categorySlug;

  /// A preset's code, or `custom`, or empty when nothing is chosen yet.
  final String sizeCode;
  final String sizeCustom;

  final String fromLocation;
  final String toLocation;
  final String contactPhone;

  /// Whether the chosen category resolved to any presets at all. When it did
  /// not, the form shows a free-text field instead of chips and size stops
  /// being required — a catalogue we could not load must never be a wall.
  final bool categoryHasPresets;

  static const customSize = 'custom';

  List<ShippingField> get missing {
    final out = <ShippingField>[];

    if (source == null) return [ShippingField.source];

    if (source == ShippingSource.mambanda) {
      if (listing == null) out.add(ShippingField.item);
    } else {
      // A link is enough on its own, and so is a description. "Ship me
      // something" is not a request, but "ship me this <link>" is.
      if (productUrl.trim().isEmpty && description.trim().isEmpty) {
        out.add(ShippingField.item);
      }
    }

    if (categorySlug.trim().isEmpty) out.add(ShippingField.category);

    if (categoryHasPresets && sizeCode.trim().isEmpty) {
      out.add(ShippingField.size);
    }
    // Choosing "something else" and saying nothing is the same as choosing
    // nothing — the server refuses it, so the form should too.
    if (sizeCode == customSize && sizeCustom.trim().isEmpty) {
      out.add(ShippingField.sizeCustom);
    }

    if (fromLocation.trim().isEmpty) out.add(ShippingField.from);
    if (toLocation.trim().isEmpty) out.add(ShippingField.to);
    if (contactPhone.trim().length < 6) out.add(ShippingField.phone);

    return out;
  }

  bool get isReady => missing.isEmpty;

  ShippingDraft copyWith({
    ShippingSource? source,
    Listing? listing,
    String? productUrl,
    String? description,
    String? categorySlug,
    String? sizeCode,
    String? sizeCustom,
    String? fromLocation,
    String? toLocation,
    String? contactPhone,
    bool? categoryHasPresets,
    bool clearListing = false,
  }) =>
      ShippingDraft(
        source: source ?? this.source,
        listing: clearListing ? null : (listing ?? this.listing),
        productUrl: productUrl ?? this.productUrl,
        description: description ?? this.description,
        categorySlug: categorySlug ?? this.categorySlug,
        sizeCode: sizeCode ?? this.sizeCode,
        sizeCustom: sizeCustom ?? this.sizeCustom,
        fromLocation: fromLocation ?? this.fromLocation,
        toLocation: toLocation ?? this.toLocation,
        contactPhone: contactPhone ?? this.contactPhone,
        categoryHasPresets: categoryHasPresets ?? this.categoryHasPresets,
      );
}

/// The four screens the form is split across.
enum ShippingStep { item, route, quote, confirm }

/// Which fields each step is responsible for.
///
/// Every [ShippingField] appears here exactly once — a test holds that — so
/// the step you are on and [ShippingDraft.missing] can never disagree about
/// whether you may continue. The quote step owns nothing: it is a choice, and
/// a route the catalogue cannot price is still allowed through.
const stepFields = <ShippingStep, List<ShippingField>>{
  ShippingStep.item: [
    ShippingField.source,
    ShippingField.item,
    ShippingField.category,
    ShippingField.size,
    ShippingField.sizeCustom,
  ],
  ShippingStep.route: [ShippingField.from, ShippingField.to],
  ShippingStep.quote: [],
  ShippingStep.confirm: [ShippingField.phone],
};

extension ShippingDraftSteps on ShippingDraft {
  /// What this step still needs, in on-screen order.
  List<ShippingField> missingIn(ShippingStep step) {
    final own = stepFields[step] ?? const [];
    return missing.where(own.contains).toList(growable: false);
  }

  bool isStepReady(ShippingStep step) => missingIn(step).isEmpty;
}
