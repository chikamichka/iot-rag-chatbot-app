import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/chat_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final bool isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(
        initialIsDark: isDarkMode,
        prefs: prefs,
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return AnimatedTheme(
      data: themeProvider.isDarkMode
          ? themeProvider.darkTheme
          : themeProvider.lightTheme,
      duration: const Duration(milliseconds: 20), // Smooth fade
      curve: Curves.easeInOutQuart, 
      child: MaterialApp(
        title: 'IoT RAG Chatbot',
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.isDarkMode
            ? ThemeMode.dark
            : ThemeMode.light,
        theme: themeProvider.lightTheme,
        darkTheme: themeProvider.darkTheme,
        home: const ChatScreen(),
      ),
    );
  }
}
