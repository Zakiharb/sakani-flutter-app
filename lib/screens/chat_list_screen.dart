// D:\ttu_housing_app\lib\screens\chat_list_screen.dart

import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';

class ChatListScreen extends StatelessWidget {
  final void Function(String recipientId, String recipientName) onSelectChat;

  const ChatListScreen({super.key, required this.onSelectChat});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final List<ChatConversation> mockConversations = [
      ChatConversation(
        id: '1',
        participantId: '2',
        participantName: 'Zaki harb',
        lastMessage: tr(
          context,
          'Do you have a specific question? How can I help you?',
          'هل لديك سؤال محدد؟ كيف يمكنني مساعدتك؟',
        ),
        timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
        unread: 0,
      ),
      ChatConversation(
        id: '2',
        participantId: '3',
        participantName: 'Reda Ayash',
        lastMessage: tr(
          context,
          'The apartment will be available from next month.',
          'الشقة ستكون متاحة من الشهر القادم.',
        ),
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        unread: 2,
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(tr(context, 'Messages', 'الرسائل')),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: mockConversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: scheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(context, 'No messages yet', 'لا توجد رسائل بعد'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        'Start chatting with landlords by viewing apartment details and clicking "Chat with Owner".',
                        'ابدأ الدردشة مع الملاك من خلال فتح تفاصيل الشقة ثم الضغط على "الدردشة مع المالك".',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              itemCount: mockConversations.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: scheme.outlineVariant),
              itemBuilder: (context, index) {
                final c = mockConversations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primary.withOpacity(0.12),
                    child: Text(
                      c.participantName.isNotEmpty ? c.participantName[0] : '?',
                      style: TextStyle(color: scheme.primary),
                    ),
                  ),
                  title: Text(
                    c.participantName,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  subtitle: Text(
                    c.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${c.timestamp.month}/${c.timestamp.day}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (c.unread > 0) ...[
                        const SizedBox(height: 4),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: scheme.primary,
                          child: Text(
                            c.unread.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => onSelectChat(c.participantId, c.participantName),
                );
              },
            ),
    );
  }
}
