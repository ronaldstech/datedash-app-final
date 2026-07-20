import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF4D85), // Premium Pink
        primary: const Color(0xFFFF4D85),
        secondary: const Color(0xFFFF85A1),
      surface: const Color(0xFFFAFAFA),
    ),
      useMaterial3: true,
      fontFamily: 'Roboto', // Default fallback
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // For Android
          statusBarBrightness: Brightness.light, // For iOS
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF4D85), // Premium Pink
        primary: const Color(0xFFFF4D85),
        secondary: const Color(0xFFFF85A1),
        brightness: Brightness.dark,
        surface: const Color(0xFF000000), // Pure black surface
        onSurface: Colors.white,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.black, // Pure black background
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // For Android
          statusBarBrightness: Brightness.dark, // For iOS
        ),
      ),
      dividerColor: Colors.white10,
      cardColor: const Color(0xFF121212), // Slightly off-black for cards
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
    );
  }
}
