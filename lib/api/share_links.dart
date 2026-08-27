/// The shape of a shared link, in one place.
///
/// Both ends of sharing depend on this agreeing with itself: the share sheet
/// builds a URL here, and an incoming link is parsed here. The web page that
/// serves it lives in the site repo at `api/l.js`, behind the `/l/:id` rewrite
/// — change the path in one and it must change in the other, or every link
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

  /// The listing id in [uri], or null if it is not one of our listing links.
  ///
  /// Host is checked against [_knownHosts] as well as the path. Android
  /// verifies the domain before handing us an App Link, but the same parser
  /// also sees links arriving by other routes, and "any URL ending
  /// `/l/<uuid>`" is not something to open on somebody's behalf.
  static String? listingIdFrom(Uri uri) {
    if (!_knownHosts.contains(uri.host.toLowerCase())) return null;
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length != 2 || parts.first != 'l') return null;
    final id = parts[1];
    return _uuid.hasMatch(id) ? id : null;
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
}
