import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../state/app_state.dart';
import '../state/quiz_controller.dart';
import '../widgets/option_tile.dart';
import '../widgets/smart_text.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.questions,
    required this.sessionTitle,
  });

  final List<Question> questions;
  final String sessionTitle;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late QuizController _controller;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _controller = QuizController(questions: widget.questions, appState: app);
  }

  void _goToResults() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(controller: _controller, sessionTitle: widget.sessionTitle),
    ));
  }

  void _onNext() {
    if (_controller.isLast) {
      _goToResults();
    } else {
      _controller.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QuizController>.value(
      value: _controller,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await _confirmExit(context);
          if (leave && context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () async {
                final leave = await _confirmExit(context);
                if (leave && context.mounted) Navigator.of(context).pop();
              },
            ),
            title: Text(widget.sessionTitle),
            actions: [
              Consumer<QuizController>(
                builder: (context, c, _) => IconButton(
                  icon: Icon(
                    c.isBookmarked ? Icons.star_rounded : Icons.star_border_rounded,
                    color: c.isBookmarked ? Colors.amber : null,
                  ),
                  onPressed: c.toggleBookmark,
                ),
              ),
            ],
          ),
          body: Consumer<QuizController>(
            builder: (context, c, _) => _QuizBody(controller: c, onNext: _onNext),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    if (_controller.index == 0 && !_controller.answered) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('학습을 종료할까요?'),
        content: const Text('지금까지의 정답/오답 기록은 저장돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('종료')),
        ],
      ),
    );
    return result ?? false;
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({required this.controller, required this.onNext});
  final QuizController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = controller.current;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: (controller.index) / controller.total,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${controller.index + 1} / ${controller.total}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey(q.id),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  q.category,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                q.question.split('\n').first,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              if (q.question.contains('\n'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SmartText(
                    q.question.split('\n').skip(1).join('\n'),
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              const SizedBox(height: 20),
              if (q.hasOptions)
                ...List.generate(q.options.length, (i) {
                  return OptionTile(
                    index: i,
                    text: q.options[i],
                    state: _stateFor(controller, i),
                    onTap: controller.answered ? null : () => controller.selectOption(i),
                  );
                })
              else
                _ShortAnswerCard(controller: controller),
              if (controller.answered) ...[
                const SizedBox(height: 8),
                _ExplanationCard(question: q, controller: controller),
              ],
            ],
          ),
        ),
        _BottomBar(controller: controller, onNext: onNext),
      ],
    );
  }

  OptionVisualState _stateFor(QuizController c, int i) {
    if (!c.answered) return OptionVisualState.idle;
    if (i == c.current.answerIndex) return OptionVisualState.correct;
    if (i == c.selected) return OptionVisualState.wrongSelected;
    return OptionVisualState.wrongDim;
  }
}

class _ShortAnswerCard extends StatelessWidget {
  const _ShortAnswerCard({required this.controller});
  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!controller.answered) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OutlinedButton.icon(
          onPressed: controller.revealAnswer,
          icon: const Icon(Icons.visibility_rounded),
          label: const Text('정답 확인하기'),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정답',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            controller.current.answerText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.question, required this.controller});
  final Question question;
  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsSelfGrade = !question.hasOptions;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  '해설',
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            question.explanation.trim().isEmpty
                ? Text(
                    '이 문제는 별도 해설이 제공되지 않았어요. 정답을 기준으로 관련 명령어/개념을 다시 확인해보세요.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14.5, height: 1.5),
                  )
                : SmartText(
                    question.explanation,
                    style: const TextStyle(fontSize: 14.5, height: 1.55),
                  ),
            if (needsSelfGrade) ...[
              const SizedBox(height: 14),
              Text(
                '맞혔나요?',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => controller.selfGrade(false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('틀렸어요'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => controller.selfGrade(true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('맞혔어요'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onNext});
  final QuizController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canAdvance = controller.answered &&
        (controller.current.hasOptions ||
            controller.correctCount + controller.wrongCount >= controller.index + 1);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canAdvance ? onNext : null,
          child: Text(controller.isLast ? '결과 보기' : '다음 문제'),
        ),
      ),
    );
  }
}
