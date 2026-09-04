import 'package:flutter/material.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

/// Inbox of chat threads.
///
/// Threads arrive already shaped from the caller's side — `counterparty` is
/// whoever they're talking to and `unread` is their own count — so this screen
/// never has to work out which side of a conversation the user is on.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => ChatInboxScreenState();
}

class ChatInboxScreenState extends State<ChatInboxScreen> {
  // Errors are stored as sentinels and translated in build(), since _load runs
  // from initState — before localizations are available.
  static const _errSignIn = '__signin__';
  static const _errLoad = '__load__';

  final _chat = ChatRepository.instance;
  bool _isLoading = true;
  String? _error;

  /// Search and filter are deliberately client-side.
  ///
  /// The inbox is already loaded in full — the repository holds every thread —
  /// so filtering here is instant and works offline. A server-side search would
  /// add a round trip and an empty-state race for a list that is, for most
  /// people, a dozen rows long.
  final _searchController = TextEditingController();
  String _query = '';
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Re-read the inbox.
  ///
  /// The shell keeps this screen alive inside an IndexedStack, so initState
  /// runs once at launch and never again. Without somebody asking it to look
  /// again, a conversation that starts after the app opened never appears.
  void reload() => _load();

  Future<void> _load() async {
    if (AuthService.instance.session == null) {
      setState(() {
        _isLoading = false;
        _error = _errSignIn;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _chat.refresh();
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = _errLoad;
          _isLoading = false;
        });
      }
    }
  }

  String _timeLabel(BuildContext context, DateTime? at) {
    if (at == null) return '';
    final l10n = context.l10n;
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inHours < 1) return l10n.timeMinutesShort(diff.inMinutes);
    if (diff.inDays < 1) return l10n.timeHoursShort(diff.inHours);
    if (diff.inDays < 7) return l10n.timeDaysShort(diff.inDays);
    return '${at.day}/${at.month}';
  }

  /// Matches the name the user sees and the listing title beneath it — the two
  /// things actually on screen. Searching fields the row doesn't show would
  /// return rows with no visible reason for matching.
  List<Conversation> _filter(List<Conversation> all) {
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      if (_unreadOnly && c.unread <= 0) return false;
      if (q.isEmpty) return true;
      final name = c.counterparty?.displayName ?? '';
      final title = c.listing?.title ?? '';
      return name.toLowerCase().contains(q) || title.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messagesTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 44, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                            _error == _errSignIn
                                ? l10n.signInToSeeMessages
                                : l10n.couldNotLoadMessages,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                            onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                )
              : ValueListenableBuilder<List<Conversation>>(
                  valueListenable: _chat.threads,
                  builder: (context, chats, _) {
                    final unreadThreads =
                        chats.where((c) => c.unread > 0).length;
                    final visible = _filter(chats);
                    return Column(
                      children: [
                        // The header stays put whether or not there are results,
                        // so a search that matches nothing can still be cleared.
                        if (chats.isNotEmpty)
                          _InboxHeader(
                            controller: _searchController,
                            onQueryChanged: (v) => setState(() => _query = v),
                            unreadOnly: _unreadOnly,
                            unreadThreads: unreadThreads,
                            onFilterChanged: (v) =>
                                setState(() => _unreadOnly = v),
                          ),
                        Expanded(
                          child: visible.isEmpty
                              ? _EmptyState(
                                  onRefresh: _load,
                                  message: chats.isEmpty
                                      ? l10n.noChatsYet
                                      : _unreadOnly && _query.trim().isEmpty
                                          ? l10n.messagesNoUnread
                                          : l10n.messagesNoMatches,
                                )
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  child: ListView.separated(
                                    // Clearance for the docked publish button.
                                    padding:
                                        const EdgeInsets.only(bottom: 96),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) =>
                                        _buildRow(context, visible[index]),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildRow(BuildContext context, Conversation chat) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final name = chat.counterparty?.displayName ?? l10n.chatUnknownUser;
    final avatar = chat.counterparty?.avatarUrl;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        backgroundImage:
            (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
        child: (avatar == null || avatar.isEmpty)
            ? Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(_timeLabel(context, chat.lastMessageAt),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
      subtitle: Text(
        chat.listing?.title ?? l10n.chatUnknownListing,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      trailing: chat.unread > 0
          ? Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Text('${chat.unread}',
                  style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            )
          : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(conversation: chat),
          ),
        );
        // Unread may have cleared while the room was open.
        _load();
      },
    );
  }
}

/// Search field and the All / Unread pair.
///
/// The deck shows a third "Archive" tab. There is no archive in the schema —
/// no column, no endpoint, nothing to put in it — so it is left out rather
/// than shipped as a tab that is permanently empty.
class _InboxHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final bool unreadOnly;
  final int unreadThreads;
  final ValueChanged<bool> onFilterChanged;

  const _InboxHeader({
    required this.controller,
    required this.onQueryChanged,
    required this.unreadOnly,
    required this.unreadThreads,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.messagesSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FilterChip(
                label: l10n.messagesFilterAll,
                selected: !unreadOnly,
                onTap: () => onFilterChanged(false),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: unreadThreads > 0
                    ? '${l10n.messagesFilterUnread} ($unreadThreads)'
                    : l10n.messagesFilterUnread,
                selected: unreadOnly,
                onTap: () => onFilterChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Lime as a fill works on either ground; lime as a label would not,
          // which is why the unselected text falls back to onSurfaceVariant.
          color: selected ? tokens.accentFill : cs.surfaceContainerHighest,
          // The unselected ground is within a shade of the page in light mode,
          // so without an outline the inactive tab reads as a word rather than
          // as something you can press.
          border: selected
              ? null
              : Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? tokens.onAccentFill : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Scrollable, so an empty inbox can still be pulled down to refresh. A centred
/// Text cannot be, which left the one screen most likely to be out of date as
/// the one screen with no way to update it.
class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String message;

  const _EmptyState({required this.onRefresh, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Center(
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }
}
