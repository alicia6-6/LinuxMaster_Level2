class Question {
  final String id;
  final String category;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String answerText;
  final String explanation;

  const Question({
    required this.id,
    required this.category,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.answerText,
    required this.explanation,
  });

  bool get hasOptions => options.isNotEmpty;

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      category: json['category'] as String? ?? '기타',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      answerIndex: json['answerIndex'] as int? ?? -1,
      answerText: json['answerText'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

/// Per-question learning state stored on-device.
enum AnswerState { unseen, correct, wrong }

class QuestionProgress {
  final String questionId;
  AnswerState lastResult;
  int correctCount;
  int wrongCount;
  bool bookmarked;

  QuestionProgress({
    required this.questionId,
    this.lastResult = AnswerState.unseen,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.bookmarked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': questionId,
        'last': lastResult.index,
        'correct': correctCount,
        'wrong': wrongCount,
        'bookmark': bookmarked,
      };

  factory QuestionProgress.fromJson(Map<String, dynamic> json) {
    return QuestionProgress(
      questionId: json['id'] as String,
      lastResult: AnswerState.values[json['last'] as int? ?? 0],
      correctCount: json['correct'] as int? ?? 0,
      wrongCount: json['wrong'] as int? ?? 0,
      bookmarked: json['bookmark'] as bool? ?? false,
    );
  }
}
