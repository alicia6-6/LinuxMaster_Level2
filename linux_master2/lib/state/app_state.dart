import 'package:flutter/material.dart';
import '../data/progress_store.dart';
import '../data/question_repository.dart';
import '../models/question.dart';

class CategoryStat {
  final String category;
  final int total;
  final int solved;
  final int correct;

  const CategoryStat({
    required this.category,
    required this.total,
    required this.solved,
    required this.correct,
  });

  double get progressRatio => total == 0 ? 0 : solved / total;
  double get accuracyRatio => solved == 0 ? 0 : correct / solved;
}

/// App-wide state: the full question bank, per-question learning progress,
/// and theme preference. Screens read this via [Provider]/[Consumer] and
/// call the mutation methods below, which persist to disk automatically.
class AppState extends ChangeNotifier {
  final QuestionRepository _repository = QuestionRepository();
  final ProgressStore _store = ProgressStore();

  List<Question> _questions = [];
  Map<String, QuestionProgress> _progress = {};
  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  List<Question> get questions => _questions;
  bool get loading => _loading;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    final results = await Future.wait([
      _repository.loadAll(),
      _store.loadProgress(),
      _store.loadThemeMode(),
    ]);
    _questions = results[0] as List<Question>;
    _progress = results[1] as Map<String, QuestionProgress>;
    final themeString = results[2] as String?;
    _themeMode = switch (themeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _loading = false;
    notifyListeners();
  }

  QuestionProgress progressFor(String id) =>
      _progress[id] ?? QuestionProgress(questionId: id);

  List<String> get categoriesInOrder {
    final seen = <String>[];
    for (final q in _questions) {
      if (!seen.contains(q.category)) seen.add(q.category);
    }
    return seen;
  }

  List<Question> questionsInCategory(String category) =>
      _questions.where((q) => q.category == category).toList();

  List<Question> get wrongQuestions => _questions
      .where((q) => progressFor(q.id).lastResult == AnswerState.wrong)
      .toList();

  List<Question> get bookmarkedQuestions =>
      _questions.where((q) => progressFor(q.id).bookmarked).toList();

  int get totalCount => _questions.length;

  int get solvedCount =>
      _progress.values.where((p) => p.lastResult != AnswerState.unseen).length;

  int get correctCount =>
      _progress.values.where((p) => p.lastResult == AnswerState.correct).length;

  double get overallAccuracy =>
      solvedCount == 0 ? 0 : correctCount / solvedCount;

  CategoryStat statFor(String category) {
    final qs = questionsInCategory(category);
    int solved = 0;
    int correct = 0;
    for (final q in qs) {
      final p = progressFor(q.id);
      if (p.lastResult != AnswerState.unseen) solved++;
      if (p.lastResult == AnswerState.correct) correct++;
    }
    return CategoryStat(
      category: category,
      total: qs.length,
      solved: solved,
      correct: correct,
    );
  }

  Future<void> recordAnswer(String questionId, bool wasCorrect) async {
    final p = _progress.putIfAbsent(
      questionId,
      () => QuestionProgress(questionId: questionId),
    );
    p.lastResult = wasCorrect ? AnswerState.correct : AnswerState.wrong;
    if (wasCorrect) {
      p.correctCount++;
    } else {
      p.wrongCount++;
    }
    notifyListeners();
    await _store.saveProgress(_progress);
  }

  Future<void> toggleBookmark(String questionId) async {
    final p = _progress.putIfAbsent(
      questionId,
      () => QuestionProgress(questionId: questionId),
    );
    p.bookmarked = !p.bookmarked;
    notifyListeners();
    await _store.saveProgress(_progress);
  }

  Future<void> resetProgress() async {
    _progress = {};
    notifyListeners();
    await _store.saveProgress(_progress);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final s = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _store.saveThemeMode(s);
  }
}
