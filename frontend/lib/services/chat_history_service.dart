import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class ChatHistoryService {
  static const String _historyKey = 'chat_history';
  
  Future<void> saveMessage(Message message) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    
    history.add({
      'content': message.content,
      'isUser': message.isUser,
      'timestamp': message.timestamp.toIso8601String(),
    });
    
    await prefs.setString(_historyKey, jsonEncode(history));
  }
  
  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) return [];
    
    return List<Map<String, dynamic>>.from(jsonDecode(historyJson));
  }
  
  Future<List<Message>> getMessages() async {
    final history = await getHistory();
    return history.map((item) {
      return Message(
        content: item['content'] as String,
        isUser: item['isUser'] as bool,
        timestamp: DateTime.parse(item['timestamp'] as String),
      );
    }).toList();
  }
  
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}