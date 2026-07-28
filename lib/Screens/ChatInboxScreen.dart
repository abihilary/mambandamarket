import 'package:flutter/material.dart';
import '../Service/ChatRoomScreen.dart';
import '../Service/ChatService.dart';


class ChatInboxScreen extends StatelessWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages & Chats', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<List<ChatConversation>>(
        valueListenable: ChatService().activeChatsNotifier,
        builder: (context, chats, _) {
          if (chats.isEmpty) {
            return const Center(
              child: Text('No active chats yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final lastMessage = chat.messages.isNotEmpty ? chat.messages.last.text : '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(
                    chat.sellerName[0],
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
                title: Text(chat.sellerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${chat.itemTitle}: $lastMessage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(conversation: chat),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}