import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final ThemeMode mode;
  final Color primaryColor;
  ThemeState({required this.mode, required this.primaryColor});
  ThemeState copyWith({ThemeMode? mode, Color? primaryColor}) {
    return ThemeState(
      mode: mode ?? this.mode,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(mode: ThemeMode.system, primaryColor: const Color(0xFF8AC926))) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark');
    final colorValue = prefs.getInt('primaryColor');
    ThemeMode m = ThemeMode.system;
    if (isDark != null) m = isDark ? ThemeMode.dark : ThemeMode.light;
    Color c = const Color(0xFF8AC926);
    if (colorValue != null) c = Color(colorValue);
    state = ThemeState(mode: m, primaryColor: c);
  }

  Future<void> toggleMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    state = state.copyWith(mode: isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setPrimaryColor(Color c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', c.value);
    state = state.copyWith(primaryColor: c);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ThemeNotifier());