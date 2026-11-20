/// The shape of a shared link, in one place.
///
/// Both ends of sharing depend on this agreeing with itself: the share sheet
/// builds a URL here, and an incoming link is parsed here. The web page that
/// serves it lives in the site repo at `api/l.js` (a listing, `/l/:id`) and
/// `api/s.js` (a seller's shop, `/s/:id`) — change a path in one and it must
/// change in the other, and in the Android intent filter, or every link
/// already sent to somebody stops resolving.
class ShareLinks {
  const ShareLinks._();

  /// Public site. Deliberately not the API host: a person receiving this taps
  /// it in WhatsApp long before they have the app, and what they need is a
  /// page, not JSON.
  static const String siteBase = 'https://mambandamarket.com';

  /// Hosts a listing link may legitimately arrive on.
  ///
  /// The site moved to its own domain, and a link is not a page load — it is a
  /// message sitting in somebody's WhatsApp, possibly for months. Every link
  /// shared before the move names the old host, and dropping it here would
  /// mean the app declines to open its own links and hands them to a browser.
  /// New links use [siteBase]; old ones keep working, which is the whole
  /// reason the old host still serves.
  static const List<String> _knownHosts = [
    'mambandamarket.com',
    'www.mambandamarket.com',
    'mambandamarket.blacksilvergroups.xyz',
  ];

  static Uri listing(String id) => Uri.parse('$siteBase/l/$id');

  /// A seller's shop, by the seller's user id: the same id the profile screen
  /// opens with, so an individual seller and a company storefront share one
  /// link shape.
  static Uri shop(String userId) => Uri.parse('$siteBase/s/$userId');

  /// An invite: the referral code rides in the link, so whoever opens it
  /// never has to type it. Served by the site's `api/r.js`.
  static Uri invite(String code) =>
      Uri.parse('$siteBase/r/${Uri.encodeComponent(code.trim().toUpperCase())}');

  /// A category on the site's homepage tiles: `/c/<slug>` (api/c.js).
  static Uri category(String slug) => Uri.parse('$siteBase/c/${Uri.encodeComponent(slug)}');

  /// The category slug in [uri], or null if it is not one of our category links.
  static String? categorySlugFrom(Uri uri) {
    if (!_knownHosts.contains(uri.host.toLowerCase())) return null;
    return categorySlugFromPath(uri.path);
  }

  /// The slug in a bare path like `/c/food-drink`, for the web app.
  static String? categorySlugFromPath(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length != 2 || parts.first != 'c') return null;
    final slug = Uri.decodeComponent(parts[1]).trim().toLowerCase();
    return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug) && slug.length <= 60 ? slug : null;
  }

  /// The referral code in [uri], or null if it is not one of our invite links.
  static String? inviteCodeFrom(Uri uri) {
    if (!_knownHosts.contains(uri.host.toLowerCase())) return null;
    return inviteCodeFromPath(uri.path);
  }

  /// The code in a bare path like `/r/WIL374`, for the web app.
  static String? inviteCodeFromPath(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length != 2 || parts.first != 'r') return null;
    final code = Uri.decodeComponent(parts[1]).trim().toUpperCase();
    // The server's own rule for a code: 3–20 letters and digits.
    return RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(code) ? code : null;
  }

  /// The listing id in [uri], or null if it is not one of our listing links.
  ///
  /// Host is checked against [_knownHosts] as well as the path. Android
  /// verifies the domain before handing us an App Link, but the same parser
  /// also sees links arriving by other routes, and "any URL ending
  /// `/l/<uuid>`" is not something to open on somebody's behalf.
  static String? listingIdFrom(Uri uri) {
    if (!_knownHosts.contains(uri.host.toLowerCase())) return null;
    return listingIdFromPath(uri.path);
  }

  /// The listing id in a bare path like `/l/<uuid>`. For the web app, whose
  /// own address is the link — the host there is ours by definition.
  static String? listingIdFromPath(String path) => _idFromPath(path, 'l');

  /// The seller id in [uri], or null if it is not one of our shop links.
  /// Host checked as for [listingIdFrom].
  static String? shopIdFrom(Uri uri) {
    if (!_knownHosts.contains(uri.host.toLowerCase())) return null;
    return shopIdFromPath(uri.path);
  }

  /// The seller id in a bare path like `/s/<uuid>`, for the web app.
  static String? shopIdFromPath(String path) => _idFromPath(path, 's');

  static String? _idFromPath(String path, String prefix) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length != 2 || parts.first != prefix) return null;
    final id = parts[1];
    return _uuid.hasMatch(id) ? id : null;
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
}
