import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_service.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import '../theme/breakpoints.dart';
import 'safe_bottom.dart';

/// Whether somebody is signed in, asking them to if not.
///
/// The web app lets visitors browse without an account — they arrive from the
/// website and from shared listing links, and a sign-up wall before they have
/// seen a single item is where they leave. Everything that needs an account
/// (saving, messaging, buying, selling, reporting) calls this first. It returns
/// true when there is a session; otherwise it explains why in [reason] and
/// offers the two ways in, and returns false.
///
/// [returnToListing], when given, is reopened after signing in, so a visitor
/// who tapped "Message seller" lands back on that listing rather than on the
/// feed. Kept on disk: Google sign-in on the web leaves the page and comes back.
Future<bool> requireAccount(
  BuildContext context,
  String reason, {
  String? returnToListing,
}) async {
  if (AuthService.instance.session != null) return true;
  if (returnToListing != null) await ReturnTo.listing(returnToListing);
  if (!context.mounted) return false;

  final l10n = context.l10n;
  final tokens = context.tokens;
  final theme = Theme.of(context);

  Widget body(BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, safeBottom(ctx, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_open_rounded, size: 36, color: tokens.accentInk),
            const SizedBox(height: 12),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.guestGateBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/welcome');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accentFill,
                foregroundColor: tokens.onAccentFill,
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(l10n.createAccount),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/login');
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(l10n.logIn),
            ),
          ],
        ),
      );

  // A dialog on a desktop, a sheet on a phone: a sheet the full width of a
  // 1440px window reads as a page footer, not a question.
  if (context.isWideLayout) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Breakpoints.auth),
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: body(ctx),
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: body,
    );
  }
  return false;
}

/// A listing to reopen once a visitor has signed in. See [requireAccount].
abstract final class ReturnTo {
  static const _key = 'return_to_listing';

  static Future<void> listing(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, id);
    } catch (_) {
      // Private browsing can refuse storage. They land on Home instead.
    }
  }

  /// The listing to reopen, cleared as it is read. Null when there is none or
  /// nobody is signed in yet.
  static Future<String?> consume() async {
    if (AuthService.instance.session == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_key);
      if (id != null) await prefs.remove(_key);
      return id;
    } catch (_) {
      return null;
    }
  }
}
