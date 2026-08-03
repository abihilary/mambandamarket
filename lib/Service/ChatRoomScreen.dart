import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'document_picker.dart';

/// A single chat thread.
///
/// Messages are fetched over REST and refreshed on a timer. The Socket.IO
/// service will later push them instead, but the payload shape is the same, so
/// that swap is a transport change rather than a rewrite of this screen.
///
/// Sending is optimistic: the bubble is appended the moment Send is tapped and
/// only then reconciled with the server, so the thread never feels like it is
/// waiting on the network. Attachments follow the same path — the local file is
/// previewed while it uploads.
class ChatRoomScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatRoomScreen({super.key, required this.conversation});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  // Sentinel stored in [_error] when the generic load failure fires. It is
  // translated in build(), since _load() can run from initState (pre-build).
  static const _loadErrorSentinel = ' chatLoadError';

  /// Attachments above this never leave the device — the upload would stall on
  /// a mobile connection and Storage would reject it anyway.
  static const _maxAttachmentMb = 20;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chat = ChatRepository.instance;

  List<Message> _messages = [];

  /// Local files for messages still in flight, keyed by their temporary id, so
  /// an outgoing photo can be previewed before the server has ever seen it.
  final Map<String, File> _localFiles = {};

  bool _isLoading = true;
  String? _error;
  Timer? _poll;
  int _seq = 0;

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
      // Keep anything this device hasn't successfully sent yet — a refresh
      // must never drop a pending upload or a failed message awaiting retry.
      final unsent =
          _messages.where((m) => m.sendState != MessageSendState.sent).toList();
      final grew = page.items.length + unsent.length != _messages.length;
      setState(() {
        _messages = [...page.items, ...unsent];
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
          _error = _loadErrorSentinel;
          _isLoading = false;
        });
      }
    }
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  String _tempId() => 'local:${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// Append the bubble immediately, then let [_deliver] catch the server up.
  void _sendText() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    final optimistic = Message(
      id: _tempId(),
      conversationId: widget.conversation.id,
      senderId: _myId,
      body: text,
      createdAt: DateTime.now(),
      sendState: MessageSendState.pending,
    );
    setState(() => _messages = [..._messages, optimistic]);
    _scrollToBottom();
    _deliver(optimistic);
  }

  void _sendFile(File file, String name) {
    final optimistic = Message(
      id: _tempId(),
      conversationId: widget.conversation.id,
      senderId: _myId,
      // The path drives both the file-name label and the image/doc decision.
      attachmentPath: name,
      createdAt: DateTime.now(),
      sendState: MessageSendState.pending,
    );
    _localFiles[optimistic.id] = file;
    setState(() => _messages = [..._messages, optimistic]);
    _scrollToBottom();
    _deliver(optimistic);
  }

  /// Upload (if needed) and post [optimistic], then swap it for the server row.
  /// A failure leaves the bubble in place marked failed, so nothing is lost and
  /// the user can retry with a tap.
  Future<void> _deliver(Message optimistic) async {
    try {
      final file = _localFiles[optimistic.id];
      final path = file == null
          ? null
          : await ListingsRepository.instance.uploadChatFile(file);

      final sent = await _chat.send(
        widget.conversation.id,
        body: optimistic.body,
        attachmentPath: path,
      );
      if (!mounted) return;
      _localFiles.remove(optimistic.id);
      setState(() {
        _messages = [
          for (final m in _messages) if (m.id == optimistic.id) sent else m,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m.id == optimistic.id)
              m.copyWith(sendState: MessageSendState.failed)
            else
              m,
        ];
      });
    }
  }

  void _retry(Message failed) {
    setState(() {
      _messages = [
        for (final m in _messages)
          if (m.id == failed.id)
            m.copyWith(sendState: MessageSendState.pending)
          else
            m,
      ];
    });
    _deliver(failed);
  }

  // ── Attaching ─────────────────────────────────────────────────────────────

  Future<void> _openAttachSheet() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chatAttachPhoto),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.chatAttachCamera),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            if (DocumentPicker.isSupported)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(l10n.chatAttachDocument),
                onTap: () => Navigator.pop(sheetContext, 'document'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.chatAttachCancel),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'document') {
      try {
        final picked = await DocumentPicker.pick();
        if (picked == null) return;
        _attachIfAllowed(picked.file, picked.name);
      } on PlatformException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.chatUploadFailed)),
          );
        }
      }
      return;
    }

    final shot = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (shot == null) return;
    _attachIfAllowed(File(shot.path), shot.name);
  }

  void _attachIfAllowed(File file, String name) {
    final mb = file.lengthSync() / (1024 * 1024);
    if (mb > _maxAttachmentMb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chatFileTooLarge(_maxAttachmentMb)),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    _sendFile(file, name);
  }

  Future<void> _openAttachment(Message m) async {
    final url = m.attachmentUrl;
    if (url == null) return;
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatOpenFailed)),
      );
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

  // ── Attachment rendering ──────────────────────────────────────────────────

  Widget _attachment(Message m, bool mine) {
    final cs = Theme.of(context).colorScheme;
    final local = _localFiles[m.id];

    if (m.attachmentIsImage) {
      final image = local != null
          ? Image.file(local, width: 180, fit: BoxFit.cover)
          : (m.attachmentUrl != null
              ? Image.network(m.attachmentUrl!,
                  width: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink())
              : const SizedBox.shrink());
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: m.attachmentUrl == null ? null : () => _openAttachment(m),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
        ),
      );
    }

    // Documents: a tappable chip showing the real file name.
    final fg = mine ? cs.onPrimary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: m.attachmentUrl == null ? null : () => _openAttachment(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: mine
                ? cs.onPrimary.withValues(alpha: 0.14)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 20, color: fg),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  m.attachmentName ?? context.l10n.chatAttachmentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final other = widget.conversation.counterparty;
    final name = other?.displayName ?? l10n.chatDefaultUser;
    final listing = widget.conversation.listing;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
              backgroundImage: (other?.avatarUrl?.isNotEmpty ?? false)
                  ? NetworkImage(other!.avatarUrl!)
                  : null,
              child: (other?.avatarUrl?.isNotEmpty ?? false)
                  ? null
                  : Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: cs.onPrimary),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimary)),
                  Text(
                    listing?.title ?? l10n.chatDefaultListing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onPrimary.withValues(alpha: 0.7)),
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
              color: cs.surface,
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
                          width: 45,
                          height: 45,
                          color: cs.surfaceContainerHighest),
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
                            style: TextStyle(
                                color: cs.primary,
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
                            Text(
                                _error == _loadErrorSentinel
                                    ? l10n.chatLoadError
                                    : _error!,
                                style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 12),
                            OutlinedButton(
                                onPressed: () => _load(),
                                child: Text(l10n.chatTryAgain)),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(l10n.chatEmpty,
                                style: TextStyle(color: cs.onSurfaceVariant)),
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
                                child: GestureDetector(
                                  onTap:
                                      m.hasFailed ? () => _retry(m) : null,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 2),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.75),
                                        decoration: BoxDecoration(
                                          color: mine
                                              ? cs.primary
                                              : cs.surface,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        // A message still in flight is dimmed
                                        // until the server confirms it.
                                        child: Opacity(
                                          opacity: m.isPending ? 0.75 : 1,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (m.hasAttachment)
                                                _attachment(m, mine),
                                              if ((m.body ?? '').isNotEmpty)
                                                Text(
                                                  m.body!,
                                                  style: TextStyle(
                                                      color: mine
                                                          ? cs.onPrimary
                                                          : cs.onSurface),
                                                ),
                                              const SizedBox(height: 3),
                                              Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Text(_time(m.createdAt),
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: mine
                                                              ? cs.onPrimary
                                                                  .withValues(
                                                                      alpha:
                                                                          0.7)
                                                              : cs.onSurfaceVariant)),
                                                  if (mine) ...[
                                                    const SizedBox(width: 4),
                                                    _statusIcon(m),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (m.hasFailed)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8, right: 4),
                                          child: Text(
                                            l10n.chatSendFailed,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.danger),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Composer
          Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 12),
            color: cs.surface,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: cs.primary,
                    tooltip: l10n.chatAttach,
                    onPressed: _openAttachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.chatInputHint,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: cs.primary,
                    // Always live: sending no longer blocks on the network.
                    child: IconButton(
                      icon: Icon(Icons.send, color: cs.onPrimary, size: 20),
                      onPressed: _sendText,
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

  Widget _statusIcon(Message m) {
    // These sit inside the outgoing bubble, which is filled with the brand
    // colour — everything here has to be an `onPrimary` tint to stay legible
    // against lime in the dark theme as well as near-black in the light one.
    final onBubble = Theme.of(context).colorScheme.onPrimary;
    if (m.hasFailed) {
      return const Icon(Icons.error_outline, size: 13, color: AppColors.danger);
    }
    if (m.isPending) {
      return Icon(Icons.schedule,
          size: 13, color: onBubble.withValues(alpha: 0.7));
    }
    // Read vs delivered is carried by the glyph (done_all vs done); the read
    // state just gets the fuller-strength tint.
    return Icon(
      m.isRead ? Icons.done_all : Icons.done,
      size: 13,
      color: m.isRead ? onBubble : onBubble.withValues(alpha: 0.7),
    );
  }
}
