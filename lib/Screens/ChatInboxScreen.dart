import 'package:flutter/material.dart';

import '../Service/ChatRoomScreen.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';

/// Inbox of chat threads.
///
/// Threads arrive already shaped from the caller's side — `counterparty` is
/// whoever they're talking to and `unread` is their own count — so this screen
/// never has to work out which side of a conversation the user is on.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _chat = ChatRepository.instance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (AuthService.instance.session == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sign in to see your messages.';
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
          _error = 'Could not load your messages.';
          _isLoading = false;
        });
      }
    }
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${at.day}/${at.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages & Chats',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Icon(Icons.cloud_off, size: 44, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : ValueListenableBuilder<List<Conversation>>(
                  valueListenable: _chat.threads,
                  builder: (context, chats, _) {
                    if (chats.isEmpty) {
                      return const Center(
                        child: Text('No active chats yet.',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final name =
                              chat.counterparty?.displayName ?? 'Utilisateur';
                          final avatar = chat.counterparty?.avatarUrl;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              backgroundImage:
                                  (avatar != null && avatar.isNotEmpty)
                                      ? NetworkImage(avatar)
                                      : null,
                              child: (avatar == null || avatar.isEmpty)
                                  ? Text(
                                      name.isEmpty
                                          ? '?'
                                          : name[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo),
                                    )
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                Text(_timeLabel(chat.lastMessageAt),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                            subtitle: Text(
                              chat.listing?.title ?? 'Annonce',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            trailing: chat.unread > 0
                                ? Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: const BoxDecoration(
                                      color: Colors.indigo,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text('${chat.unread}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  )
                                : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ChatRoomScreen(conversation: chat),
                                ),
                              );
                              // Unread may have cleared while the room was open.
                              _load();
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
