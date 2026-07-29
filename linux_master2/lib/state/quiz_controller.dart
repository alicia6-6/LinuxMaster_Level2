import 'dart:math';
import 'package:flutter/material.dart';
import '../models/question.dart';
import 'app_state.dart';

/// Drives a single study session: an ordered queue of questions, the
/// currently selected option, whether the answer has been revealed, and a
/// running score. One instance is created per quiz screen and reports
/// results back into [AppState] as the learner answers each question.
class QuizController extends ChangeNotifier {
  QuizController({
    required List<Question> questions,
    required this.appState,
    this.shuffle = true,
  }) {
    _queue = List.of(questions);
    if (shuffle) _queue.shuffle(Random());
  }

  final AppState appState;
  final bool shuffle;
  late List<Question> _queue;

  int _index = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  final List<Question> _missed = [];

  Question get current => _queue[_index];
  int get index => _index;
  int get total => _queue.length;
  int? get selected => _selected;
  bool get answered => _answered;
  int get correctCount => _correct;
  int get wrongCount => _missed.length;
  List<Question> get missed => List.unmodifiable(_missed);
  bool get isLast => _index >= _queue.length - 1;
  bool get isFinished => _index >= _queue.length;
  double get progress => _queue.isEmpty ? 0 : (_index) / _queue.length;

  bool get isBookmarked => appState.progressFor(current.id).bookmarked;

  void selectOption(int optionIndex) {
    if (_answered || !current.hasOptions) return;
    _selected = optionIndex;
    _answered = true;
    final correct = optionIndex == current.answerIndex;
    if (correct) {
      _correct++;
    } else {
      _missed.add(current);
    }
    appState.recordAnswer(current.id, correct);
    notifyListeners();
  }

  /// For fill-in-the-blank style items with no multiple-choice options:
  /// the learner self-reports whether they got it right after reading the
  /// revealed answer.
  void revealAnswer() {
    if (_answered) return;
    _answered = true;
    notifyListeners();
  }

  void selfGrade(bool wasCorrect) {
    if (!_answered) return;
    if (wasCorrect) {
      _correct++;
    } else {
      _missed.add(current);
    }
    appState.recordAnswer(current.id, wasCorrect);
    notifyListeners();
  }

  void toggleBookmark() {
    appState.toggleBookmark(current.id);
    notifyListeners();
  }

  void next() {
    if (isFinished) return;
    _index++;
    _selected = null;
    _answered = false;
    notifyListeners();
  }
}
