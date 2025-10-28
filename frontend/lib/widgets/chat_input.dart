import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.isLoading,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
        if (_hasText) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      widget.onSendMessage(text);
      _controller.clear();
      setState(() => _hasText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasText 
                      ? Colors.blue.withOpacity(0.5)
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _controller,
                enabled: !widget.isLoading,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about IoT, protocols, security...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: _hasText && !widget.isLoading
                    ? LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[700]!],
                      )
                    : null,
                color: !_hasText || widget.isLoading 
                    ? (isDark ? Colors.grey[700] : Colors.grey[300])
                    : null,
                shape: BoxShape.circle,
                boxShadow: _hasText && !widget.isLoading
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                icon: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: _hasText 
                            ? Colors.white 
                            : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        size: 22,
                      ),
                onPressed: _hasText && !widget.isLoading ? _handleSend : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}