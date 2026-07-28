import 'dart:async';
import 'package:flutter/foundation.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  // Ready for JSON deserialization when backend is connected
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };
}

class ChatConversation {
  final String id;
  final String itemTitle;
  final String itemPrice;
  final String itemImageUrl;
  final String sellerName;
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.itemTitle,
    required this.itemPrice,
    required this.itemImageUrl,
    required this.sellerName,
    required this.messages,
  });
}

class ChatService {
  // Singleton instance
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // In-memory store holding active chats: Map<ChatId, ChatConversation>
  final Map<String, ChatConversation> _chats = {};

  // ValueNotifier to broadcast chat list updates to UI
  final ValueNotifier<List<ChatConversation>> activeChatsNotifier =
  ValueNotifier([]);

  // StreamControllers to push real-time message streams for open chat screens
  final Map<String, StreamController<List<ChatMessage>>> _streamControllers =
  {};

  // Get or create a conversation between buyer & seller for a given item
  ChatConversation startOrGetChat({
    required String itemTitle,
    required String itemPrice,
    required String itemImageUrl,
    required String sellerName,
  }) {
    final chatId = '${sellerName}_$itemTitle'.replaceAll(' ', '_');

    if (!_chats.containsKey(chatId)) {
      _chats[chatId] = ChatConversation(
        id: chatId,
        itemTitle: itemTitle,
        itemPrice: itemPrice,
        itemImageUrl: itemImageUrl,
        sellerName: sellerName,
        messages: [
          // Initial automated greeting message from seller
          ChatMessage(
            id: 'init_1',
            senderId: 'seller',
            text:
            'Hallo! Interessierst du dich für "$itemTitle"? Frag mich gerne!',
            timestamp: DateTime.now(),
          ),
        ],
      );
      _notifyListeners();
    }

    return _chats[chatId]!;
  }

  // Get reactive stream of messages for ChatRoomScreen
  Stream<List<ChatMessage>> getMessageStream(String chatId) {
    if (!_streamControllers.containsKey(chatId)) {
      _streamControllers[chatId] =
      StreamController<List<ChatMessage>>.broadcast();
    }

    // Push initial current state down the stream
    Future.microtask(() {
      if (_chats.containsKey(chatId)) {
        _streamControllers[chatId]?.add(List.from(_chats[chatId]!.messages));
      }
    });

    return _streamControllers[chatId]!.stream;
  }

  // Send Message Method (Add backend POST request here later)
  void sendMessage(String chatId, String text) {
    if (text.trim().isEmpty || !_chats.containsKey(chatId)) return;

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'buyer', // 'buyer' is current user
      text: text,
      timestamp: DateTime.now(),
    );

    _chats[chatId]!.messages.add(newMessage);

    // Notify active chat screen
    _streamControllers[chatId]?.add(List.from(_chats[chatId]!.messages));

    _notifyListeners();

    // Simulated automated reply from seller after 1.5 seconds
    Timer(const Duration(milliseconds: 1500), () {
      _receiveMockSellerReply(chatId);
    });
  }

  void _receiveMockSellerReply(String chatId) {
    if (!_chats.containsKey(chatId)) return;

    final autoReplies = [
      "Ja, der Artikel ist noch verfügbar!",
      "Eine Abholung in Aalen wäre heute Abend möglich.",
      "Der Preis ist im kleinen Rahmen verhandelbar."
    ];

    final replyMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'seller',
      text: (autoReplies..shuffle()).first,
      timestamp: DateTime.now(),
    );

    _chats[chatId]!.messages.add(replyMessage);

    // Broadcast updated list to dynamic listeners
    _streamControllers[chatId]?.add(List.from(_chats[chatId]!.messages));
    _notifyListeners();
  }

  void _notifyListeners() {
    activeChatsNotifier.value = _chats.values.toList();
  }
}