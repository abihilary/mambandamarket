import 'package:flutter/material.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Open the conversation with the team.
///
/// This used to be a sheet with a subject and a message that posted into a
/// queue and said thank you. It is the same team, reached the way everything
/// else in the product is reached: a thread in Messages, which shows when it
/// was read, keeps what was already said, and is still there tomorrow.
///
/// One thread per person. A second question next month belongs above the first
/// one, not in a new conversation with none of the context.
///
/// Signed-in only. The website's form still exists for people without an
/// account — there is nobody to open a thread with when there is no account.
Future<void> openSupportThread(BuildContext context) async {
  final l10n = context.l10n;
  if (AuthService.instance.session == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.supportSignInRequired)),
    );
    return;
  }

  // A spinner rather than an empty screen: opening a thread is one round trip,
  // and a tap that appears to do nothing is a tap people make twice.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final thread = await SupportRepository.instance.openThread();
    if (!context.mounted) return;
    Navigator.pop(context); // the spinner
    if (thread == null) {
      _fail(context, l10n.supportFailed);
      return;
    }
    unawaitedRefresh();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(conversation: thread)),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    _fail(context, e.code == 'support_unavailable' ? l10n.supportUnavailable : e.message);
  } catch (_) {
    if (!context.mounted) return;
    Navigator.pop(context);
    _fail(context, l10n.supportFailed);
  }
}

/// The inbox should know about the new thread without waiting for a tab switch.
void unawaitedRefresh() {
  ChatRepository.instance.refresh().catchError((_) {});
}

void _fail(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.danger),
  );
}
