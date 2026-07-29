import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';

/// A single chat thread.
///
/// Messages are fetched over REST and refreshed on a timer. The Socket.IO
/// service will later push them instead, but the payload shape is the same, so
/// that swap is a transport change rather than a rewrite of this screen.
class ChatRoomScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatRoomScreen({super.key, required this.conversation});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chat = ChatRepository.instance;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  Timer? _poll;

  String get _myId => AuthService.instance.userId ?? '';

  @override
  void initState() {
    super.initState();
    _load(markRead: true);
    // Stand-in for live delivery until the socket service exists.
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool markRead = false}) async {
    try {
      final page = await _chat.messages(widget.conversation.id);
      if (!mounted) return;
      final grew = page.items.length != _messages.length;
      setState(() {
        _messages = page.items;
        _isLoading = false;
        _error = null;
      });
      if (grew) _scrollToBottom();
      if (markRead && widget.conversation.unread > 0) {
        await _chat.markRead(widget.conversation.id);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load this conversation.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();
    try {
      final sent = await _chat.send(widget.conversation.id, body: text);
      if (!mounted) return;
      setState(() => _messages = [..._messages, sent]);
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      // Put the text back so a failed send isn't silently lost.
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _time(DateTime? at) => at == null
      ? ''
      : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final other = widget.conversation.counterparty;
    final name = other?.displayName ?? 'Utilisateur';
    final listing = widget.conversation.listing;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade200,
              backgroundImage: (other?.avatarUrl?.isNotEmpty ?? false)
                  ? NetworkImage(other!.avatarUrl!)
                  : null,
              child: (other?.avatarUrl?.isNotEmpty ?? false)
                  ? null
                  : Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                    listing?.title ?? 'Annonce',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // What the conversation is about.
          if (listing != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      listing.primaryImageUrl,
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 45, height: 45, color: Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(listing.displayPrice,
                            style: const TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            OutlinedButton(
                                onPressed: () => _load(),
                                child: const Text('Try again')),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text('Say hello to start the conversation.',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final mine = m.senderId == _myId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.75),
                                  decoration: BoxDecoration(
                                    color:
                                        mine ? Colors.indigo : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (m.attachmentUrl != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                                m.attachmentUrl!,
                                                width: 180,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox.shrink()),
                                          ),
                                        ),
                                      if ((m.body ?? '').isNotEmpty)
                                        Text(
                                          m.body!,
                                          style: TextStyle(
                                              color: mine
                                                  ? Colors.white
                                                  : Colors.black87),
                                        ),
                                      const SizedBox(height: 3),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_time(m.createdAt),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: mine
                                                      ? Colors.white70
                                                      : Colors.grey)),
                                          if (mine) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              m.isRead
                                                  ? Icons.done_all
                                                  : Icons.done,
                                              size: 13,
                                              color: m.isRead
                                                  ? Colors.lightBlueAccent
                                                  : Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Composer
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Écrire un message…',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
