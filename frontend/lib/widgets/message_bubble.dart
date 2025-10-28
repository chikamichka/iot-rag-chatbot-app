import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart' as models;

class MessageBubble extends StatelessWidget {
  final models.Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.isUser 
              ? CrossAxisAlignment.end 
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[700]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: message.isUser
                    ? null
                    : isDark 
                        ? Colors.grey[800]
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: message.isUser 
                      ? const Radius.circular(20) 
                      : const Radius.circular(4),
                  bottomRight: message.isUser 
                      ? const Radius.circular(4) 
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: message.isUser
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: message.isUser 
                          ? Colors.white 
                          : isDark 
                              ? Colors.white 
                              : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (!message.isUser) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: message.content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          tooltip: 'Copy',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (message.sources != null && message.sources!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.grey[850]!.withOpacity(0.5)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark 
                        ? Colors.grey[700]! 
                        : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.source,
                          size: 14,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sources (${message.sources!.length})',
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...message.sources!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final source = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                source.text.length > 100 
                                    ? '${source.text.substring(0, 100)}...' 
                                    : source.text,
                                style: TextStyle(
                                  color: isDark 
                                      ? Colors.grey[400] 
                                      : Colors.grey[700],
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}