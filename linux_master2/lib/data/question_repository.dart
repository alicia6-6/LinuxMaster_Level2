import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/question.dart';

class QuestionRepository {
  static const _assetPath = 'assets/data/questions.json';

  Future<List<Question>> loadAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final List<dynamic> jsonList = json.decode(raw) as List<dynamic>;
    return jsonList
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
