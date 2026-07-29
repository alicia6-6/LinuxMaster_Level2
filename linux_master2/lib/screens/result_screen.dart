import 'package:flutter/material.dart';
import '../state/quiz_controller.dart';
import '../widgets/progress_ring.dart';
import 'quiz_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    required this.sessionTitle,
  });

  final QuizController controller;
  final String sessionTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = controller.correctCount + controller.wrongCount;
    final ratio = total == 0 ? 0.0 : controller.correctCount / total;

    return Scaffold(
      appBar: AppBar(title: Text('$sessionTitle 결과'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Column(
                children: [
                  ProgressRing(value: ratio, size: 140, label: '정답률'),
                  const SizedBox(height: 16),
                  Text(
                    _messageFor(ratio),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total문항 중 ${controller.correctCount}개 정답',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF2E9E5B),
                    label: '정답',
                    value: '${controller.correctCount}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatChip(
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFE0483F),
                    label: '오답',
                    value: '${controller.wrongCount}',
                  ),
                ),
              ],
            ),
            if (controller.missed.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                '틀린 문제 다시보기',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...controller.missed.map((q) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.question.split('\n').first,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '정답: ${q.answerText}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('홈으로'),
                  ),
                ),
                const SizedBox(width: 12),
                if (controller.missed.isNotEmpty)
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (_) => QuizScreen(
                            questions: controller.missed,
                            sessionTitle: '$sessionTitle · 오답 다시풀기',
                          ),
                        ));
                      },
                      child: const Text('오답만 다시 풀기'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(double ratio) {
    if (ratio >= 0.9) return '완벽해요! 🎉';
    if (ratio >= 0.7) return '좋아요, 거의 다 왔어요!';
    if (ratio >= 0.4) return '조금만 더 복습해봐요';
    return '오답노트로 다시 정리해봐요';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          Text(label, style: TextStyle(color: color, fontSize: 12.5)),
        ],
      ),
    );
  }
}
