import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';

/// Persists per-question progress (correct/wrong counts, bookmarks) and
/// simple app-level preferences (theme mode) to on-device storage so a
/// learner's progress survives app restarts.
class ProgressStore {
  static const _progressKey = 'lm2_progress_v1';
  static const _themeKey = 'lm2_theme_mode_v1';

  Future<Map<String, QuestionProgress>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null || raw.isEmpty) return {};
    final Map<String, dynamic> decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) =>
        MapEntry(key, QuestionProgress.fromJson(value as Map<String, dynamic>)));
  }

  Future<void> saveProgress(Map<String, QuestionProgress> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      progress.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_progressKey, encoded);
  }

  Future<String?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey);
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }
}
