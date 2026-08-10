import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// The mark that says an account has actually been checked.
///
/// "Verified" here is not a self-declaration: a `company` is provisioned by an
/// admin after a physical visit, and `store_profiles.is_verified` is set by the
/// same hand. Nobody can award it to themselves, which is the only reason it is
/// worth showing — so it renders identically everywhere and never appears for
/// an account that merely calls itself a business.
class VerifiedBadge extends StatelessWidget {
  /// Icon only, no pill. For tight rows — a chat title bar, a "sold by" line —
  /// where the full badge would crowd out the name it is vouching for.
  final bool dense;

  final double size;

  const VerifiedBadge({super.key, this.dense = false, this.size = 16});

  /// Whether an account has been verified at all.
  ///
  /// Either signal counts: a company role is an admin-provisioned merchant, and
  /// a verified storefront is the same decision recorded on the shop.
  static bool applies({bool isCompany = false, bool storeVerified = false}) =>
      isCompany || storeVerified;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.verified_rounded, size: size, color: AppColors.success);
    if (dense) return icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(
            context.l10n.verifiedBadge,
            style: TextStyle(
              fontSize: size * 0.72,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
