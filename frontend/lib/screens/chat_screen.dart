import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/message.dart' as models; // Add alias here
import '../services/api_service.dart';
import '../services/chat_history_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final List<models.Message> _messages = [];
  final ApiService _apiService = ApiService();
  final ChatHistoryService _historyService = ChatHistoryService();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isLoading = false;
  bool _isConnected = false;
  bool _isListening = false;
  String _recognizedText = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Slightly longer fade
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _checkConnection();
    await _loadChatHistory();
    await _initializeSpeech();
    await _initializeNotifications();

    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for chat responses',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

Future<void> _initializeSpeech() async {
  try {
    // Initialize speech recognition
    bool available = await _speechToText.initialize(
      onError: (error) {
        print('Speech error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech error: ${error.errorMsg}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onStatus: (status) => print('Speech status: $status'),
    );
    
    if (!available) {
      print('Speech recognition not available on this device');
    }
  } catch (e) {
    print('Error initializing speech: $e');
  }
}

Future<void> _startListening() async {
  if (!_isListening) {
    // Check if speech recognition is available
    bool available = await _speechToText.initialize(
      onError: (error) => print('Speech error: $error'),
      onStatus: (status) => print('Speech status: $status'),
    );
    
    if (!available) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.mic_off, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Microphone Access'),
              ],
            ),
            content: const Text(
              'Speech recognition is not available.\n\n'
              'On macOS, please:\n'
              '1. Open System Settings\n'
              '2. Go to Privacy & Security → Microphone\n'
              '3. Enable access for this app\n'
              '4. Restart the app',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    setState(() => _isListening = true);
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }
}

Future<void> _stopListening() async {
  if (_isListening) {
    await _speechToText.stop();
    setState(() => _isListening = false);
    
    if (_recognizedText.isNotEmpty) {
      _handleSendMessage(_recognizedText);
      setState(() => _recognizedText = '');
    }
  }
}

  Future<void> _checkConnection() async {
    final isHealthy = await _apiService.checkHealth();
    setState(() {
      _isConnected = isHealthy;
    });
    if (isHealthy) {
      _animationController.forward();
    }
  }

  Future<void> _loadChatHistory() async {
    final history = await _historyService.getMessages();
    if (history.isNotEmpty) {
      setState(() {
        _messages.addAll(history);
      });
      _scrollToBottom(animated: false);
    }
  }

  void _addWelcomeMessage() {
    final welcomeMsg = models.Message(
      content:
          '👋 Hello! I\'m your IoT assistant powered by RAG and Knowledge Graphs.\n\n'
          'Ask me about:\n'
          '• IoT protocols (MQTT, CoAP, LoRaWAN)\n'
          '• Edge computing\n'
          '• IoT security practices\n'
          '• Smart home & Industrial IoT\n\n'
          '💡 You can also upload documents or use voice input!',
      isUser: false,
    );
    setState(() {
      _messages.add(welcomeMsg);
    });
    _historyService.saveMessage(welcomeMsg);
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return; // Don't send empty messages

    final userMsg = models.Message(content: text, isUser: true);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    await _historyService.saveMessage(userMsg);
    _scrollToBottom();

    try {
      final historyForContext = _messages
          .where((m) => m != userMsg)
          .toList()
          .reversed
          .take(6)
          .toList()
          .reversed
          .map((m) => {
                'content': m.content,
                'isUser': m.isUser,
              })
          .toList();

      final response = await _apiService.sendQuery(
        text,
        conversationHistory: historyForContext,
      );

      setState(() {
        _messages.add(response);
        _isLoading = false;
      });

      await _historyService.saveMessage(response);
      _scrollToBottom();

      await _showNotification(
        'IoT Assistant',
        response.content.substring(
                0, response.content.length > 50 ? 50 : response.content.length) +
            '...',
      );
    } catch (e) {
      final errorMsg = models.Message(
        content:
            '❌ Error: ${e.toString()}\n\nMake sure the backend server is running.',
        isUser: false,
      );
      setState(() {
        _messages.add(errorMsg);
        _isLoading = false;
      });
      await _historyService.saveMessage(errorMsg);
      _scrollToBottom();
    }
  }

  Future<void> _handleFileUpload() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'md'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);

        setState(() => _isLoading = true);

        final success = await _apiService.uploadDocument(file);

        final msg = models.Message(
          content: success
              ? '✅ Document "${result.files.single.name}" uploaded and indexed successfully!'
              : '❌ Failed to upload document. Please try again.',
          isUser: false,
        );

        setState(() {
          _messages.add(msg);
          _isLoading = false;
        });

        await _historyService.saveMessage(msg);
        _scrollToBottom();
      }
    } catch (e) {
      final errorMsg = models.Message(
        content: '❌ Error uploading file: $e',
        isUser: false,
      );
      setState(() {
        _messages.add(errorMsg);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear all chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyService.clearHistory();
      setState(() {
        _messages.clear();
      });
      _addWelcomeMessage();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        // This gradient is the base layer for the whole screen
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1a2333), const Color(0xFF12141d)] // Darker, richer gradient
                : [Colors.blue[50]!, Colors.purple[50]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // The AppBar is now a "floating" card
              _buildAppBar(context, isDark),
              Expanded(
                child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : _buildMessageList(),  // Remove the parameters here
    ),
              if (_isListening) _buildListeningIndicator(),
              // The input area has rounded top corners
              _buildInputArea(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// **UI Enhancement:** Floating AppBar
  /// This AppBar is a [Container] with [margin], [borderRadius],
  /// and a semi-transparent [color] to let the gradient peek through.
  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]!.withOpacity(0.85)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Colors.purple[400]!],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IoT Assistant',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                // **UI Enhancement:** Animated Fade for Connection Status
                FadeTransition(
                  opacity: _animationController.drive(CurveTween(curve: Curves.easeIn)),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _isConnected ? Colors.green : Colors.red,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark
                  ? Colors.yellow[700]
                  : Colors.blue[600],
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About'),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _showInfoDialog(context),
                ),
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('Clear History',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _clearHistory(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// **UI Enhancement:** Theme-Aware Colors
  /// Using [Theme.of(context)] properties instead of hardcoded colors.
  Widget _buildEmptyState(bool isDark) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.blue[800]!, Colors.purple[800]!]
                  : [Colors.blue[100]!, Colors.purple[100]!],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.blue[200] : Colors.blue[700],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Start a conversation',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask me anything about IoT!',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildMessageList() {
  return Column(
    children: [
      if (_messages.length == 1) _buildSampleQuestions(),
      Expanded(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: _messages.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length && _isLoading) {
              return const TypingIndicator();
            }
            
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: MessageBubble(message: _messages[index]),
            );
          },
        ),
      ),
    ],
  );
}

Widget _buildSampleQuestions() {
  final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
  final questions = [
    '💬 What is MQTT?',
    '🔒 IoT security practices',
    '🏠 Smart home protocols',
    '🏭 Industrial IoT overview',
  ];

  return Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: questions.map((question) {
        return GestureDetector(
          onTap: () => _handleSendMessage(question.replaceAll(RegExp(r'[💬🔒🏠🏭]\s*'), '')),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              question,
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

  Widget _buildListeningIndicator() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.red[400]!, Colors.red[600]!],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.red.withOpacity(0.3),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ],
    ),
    child: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.2),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 24,
                ),
              );
            },
            onEnd: () {
              // Loop animation
              if (mounted && _isListening) {
                setState(() {});
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Listening...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_recognizedText.isNotEmpty)
                  Text(
                    _recognizedText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _stopListening,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  /// **UI Enhancement:** Rounded Input Area
  /// This [Container] has rounded top corners to feel more
  /// integrated with the UI and less like a separate "stuck-on" box.
  Widget _buildInputArea(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false, // SafeArea is already applied to the whole column
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.attach_file_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: _isLoading ? null : _handleFileUpload,
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              onPressed: _isLoading
                  ? null
                  : (_isListening ? _stopListening : _startListening),
            ),
            Expanded(
              child: ChatInput(
                onSendMessage: _handleSendMessage,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.info_rounded, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text('About'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RAG-Powered IoT Chatbot',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Features:\n'
              '• Vector Search with ChromaDB\n'
              '• Knowledge Graph with Neo4j\n'
              '• Local Llama2 LLM\n'
              '• Document Upload\n'
              '• Voice Input\n'
              '• Chat History\n'
              '• Dark Mode\n'
              '• Notifications',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _speechToText.stop();
    super.dispose();
  }
}