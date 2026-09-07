import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Opens the support sheet: a subject and a message, sent to the team.
///
/// Signed-in only — the API accepts anonymous messages from the website, but
/// in the app the whole point is that the row carries who is asking, so their
/// reply lands in the right inbox without a form asking them to type it.
Future<void> showSupportSheet(BuildContext context) {
  if (AuthService.instance.session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.supportSignInRequired)),
    );
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SupportSheet(),
  );
}

class _SupportSheet extends StatefulWidget {
  const _SupportSheet();

  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  /// The API accepts en/fr/de; anything else is answered in English.
  String _locale(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return const {'en', 'fr', 'de'}.contains(code) ? code : 'en';
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final auth = AuthService.instance;
    final email = auth.user?.email;
    final subject = _subject.text.trim();
    final message = _message.text.trim();

    // The same minimums the API enforces, checked here so a too-short message
    // gets a sentence rather than a 422.
    if (subject.length < 3 || message.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportTooShort)),
      );
      return;
    }
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportSignInRequired)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SupportRepository.instance.send(
        email: email,
        name: auth.me.value?.profile?.displayName,
        subject: subject,
        message: message,
        locale: _locale(context),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.supportSent),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.isRateLimited
              ? l10n.supportTooMany
              : e.isUnauthorized
                  ? l10n.supportSignInRequired
                  : l10n.supportFailed),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.supportFailed),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final email = AuthService.instance.user?.email ?? '';

    return Padding(
      // Lift above the keyboard when a field is focused.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      // The message field plus the keyboard is taller than the report sheet,
      // so this one scrolls.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.supportTitle,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subject,
              maxLength: 150,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.supportSubject,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              maxLines: 5,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: l10n.supportMessage,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.supportReplyTo(email),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary),
                      )
                    : Text(l10n.supportSend,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
