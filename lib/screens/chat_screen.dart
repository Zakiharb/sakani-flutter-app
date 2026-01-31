// D:\ttu_housing_app\lib\screens\chat_screen.dart

import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';

class ChatScreen extends StatefulWidget {
  final String recipientName;
  final String recipientId;

  const ChatScreen({
    super.key,
    required this.recipientName,
    required this.recipientId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // رسائل تجريبية (بـ JD بدل $)
    _messages.addAll([
      ChatMessage(
        id: '1',
        senderId: widget.recipientId,
        receiverId: '1',
        message:
            'مرحباً! لقد رأيت استفسارك عن الشقة. كيف يمكنني مساعدتك؟',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      ChatMessage(
        id: '2',
        senderId: '1',
        receiverId: widget.recipientId,
        message: 'أردت الاستفسار عن المزيد من التفاصيل حول الشقة.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 50)),
      ),
      ChatMessage(
        id: '3',
        senderId: widget.recipientId,
        receiverId: '1',
        message: 'هل لديك سؤال محدد؟ كيف يمكنني مساعدتك؟',
        timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: '1',
      receiverId: widget.recipientId,
      message: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(msg);
      _controller.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(         
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientName),
            Text(
              tr(context, 'Online', 'متصل الآن'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        
        actions: [
          IconButton(
            onPressed: () {
              debugPrint('Calling ${widget.recipientName}');
            },
            icon: const Icon(Icons.phone_outlined),
          ),
        ],
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isOwn = msg.senderId == '1';

                final bubbleColor = isOwn
                    ? scheme.primary
                    : scheme.surfaceContainerHighest;
                final textColor = isOwn ? Colors.white : scheme.onSurface;

                return Align(
                  alignment: isOwn
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isOwn ? 16 : 4),
                        bottomRight: Radius.circular(isOwn ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.message, style: TextStyle(color: textColor)),
                        const SizedBox(height: 4),
                        Text(
                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: isOwn
                                ? Colors.white70
                                : scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.attach_file_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: tr(
                        context,
                        'Type a message...',
                        'اكتب رسالة...',
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send_rounded, color: scheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
