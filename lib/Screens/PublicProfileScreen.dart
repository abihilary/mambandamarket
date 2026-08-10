import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Components/ItemCard.dart';
import '../Components/ItemDetailScreen.dart';
import '../Components/VerifiedBadge.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';

/// Somebody else's profile: who they are, and what they are selling.
///
/// The same screen serves a buyer you are chatting with, an individual seller
/// and a company storefront, because you reach it by tapping a name — the app
/// finds out which it is from the answer. A company gets its banner, logo,
/// verified mark and support line; a buyer gets a card and nothing else, which
/// is the honest rendering of an account with nothing to show.
class PublicProfileScreen extends StatefulWidget {
  final String userId;

  /// Shown while the request is in flight, so the screen opens with the name
  /// you just tapped instead of a spinner over an empty bar.
  final String? initialName;

  const PublicProfileScreen({super.key, required this.userId, this.initialName});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _data;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await UsersRepository.instance.profile(widget.userId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _callSupport(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openListing(Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          title: listing.title,
          price: listing.displayPrice,
          imageUrl: listing.primaryImageUrl,
          images: listing.imageUrls,
          listingId: listing.id,
          listing: listing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = _data;
    final title = data?.profile.displayName ?? widget.initialName ?? l10n.profileFallbackName;

    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed || data == null
              ? _ErrorState(onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _Header(data: data, onCallSupport: _callSupport),
                      _Shop(data: data, onOpen: _openListing),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.profileLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.profileRetry)),
          ],
        ),
      ),
    );
  }
}

/// Identity: banner, avatar/logo, name, verified mark, city, bio, rating and —
/// for a storefront only — the published support number.
class _Header extends StatelessWidget {
  final PublicProfile data;
  final ValueChanged<String> onCallSupport;

  const _Header({required this.data, required this.onCallSupport});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = data.profile;
    final store = data.store;

    final name = store?.shopName.isNotEmpty == true
        ? store!.shopName
        : (profile.displayName ?? l10n.profileFallbackName);
    // A store's logo stands in for the avatar: on a storefront the brand is
    // the identity, not the person who happens to own the account.
    final imageUrl = (store?.logoUrl?.isNotEmpty ?? false) ? store!.logoUrl : profile.avatarUrl;
    // A company is admin-provisioned after a verification visit, so the role is
    // as good a signal as the store flag. Keying only on the store meant an
    // account whose subtitle read "Verified business" showed no mark at all
    // whenever it had no storefront row — the claim without the evidence.
    final verified = VerifiedBadge.applies(
      isCompany: profile.isCompany,
      storeVerified: store?.isVerified ?? false,
    );
    // Hoisted so the analyzer can see it is non-null inside the button's
    // callback — a `store?.supportPhone?.isNotEmpty` guard does not promote.
    final supportPhone = store?.supportPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store?.bannerUrl?.isNotEmpty ?? false)
          SizedBox(
            height: 132,
            child: Image.network(
              store!.bannerUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                    backgroundImage:
                        (imageUrl?.isNotEmpty ?? false) ? NetworkImage(imageUrl!) : null,
                    child: (imageUrl?.isNotEmpty ?? false)
                        ? null
                        : Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // The badge carries the tick, so the name does not need
                        // one too — and the role line below stays plain
                        // ("Business", not "Verified business") rather than
                        // making the same claim a third time.
                        if (verified)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: VerifiedBadge(),
                          ),
                        Text(
                          _roleLabel(l10n, profile, store),
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                        if (profile.city?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(profile.city!,
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (data.ratingCount > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(
                      data.ratingAverage.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(l10n.profileRatingCount(data.ratingCount),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ],
              if (store?.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                Text(store!.description!,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
              ] else if (profile.bio?.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                Text(profile.bio!,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
              ],
              // Only a storefront has a number here. A personal phone is not
              // public, and the server does not send one.
              if (supportPhone != null && supportPhone.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => onCallSupport(supportPhone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(supportPhone),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(height: 1),
            ],
          ),
        ),
      ],
    );
  }

  String _roleLabel(AppLocalizations l10n, Profile profile, Store? store) {
    if (profile.isCompany) return l10n.profileRoleCompany;
    if (store != null || profile.isSeller) return l10n.profileRoleSeller;
    return l10n.profileRoleBuyer;
  }
}

/// Their shop. Empty is a real answer — most accounts are buyers.
class _Shop extends StatelessWidget {
  final PublicProfile data;
  final ValueChanged<Listing> onOpen;

  const _Shop({required this.data, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final listings = data.listings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileShopTitle(listings.length),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (listings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: cs.onSurfaceVariant),
                    const SizedBox(height: 10),
                    Text(
                      l10n.profileShopEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listings.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (_, i) {
                final item = listings[i];
                return ItemCard(
                  imageUrl: item.primaryImageUrl,
                  title: item.title,
                  price: item.displayPrice,
                  onTap: () => onOpen(item),
                );
              },
            ),
        ],
      ),
    );
  }
}
