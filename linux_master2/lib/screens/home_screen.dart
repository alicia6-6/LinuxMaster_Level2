import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../state/app_state.dart';
import '../widgets/category_card.dart';
import '../widgets/progress_ring.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _startSession(BuildContext context, List<Question> questions, String title) {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 문제가 없어요.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizScreen(questions: questions, sessionTitle: title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final categories = app.categoriesInOrder;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('리눅스마스터 2급 암기장'),
            actions: [
              IconButton(
                tooltip: '테마',
                onPressed: () => _showThemeSheet(context, app),
                icon: const Icon(Icons.brightness_6_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: _HeroProgressCard(app: app),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.shuffle_rounded,
                      label: '전체 학습',
                      subtitle: '${app.totalCount}문항 랜덤',
                      color: scheme.primary,
                      onColor: scheme.onPrimary,
                      onTap: () => _startSession(context, app.questions, '전체 학습'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.error_outline_rounded,
                      label: '오답노트',
                      subtitle: '${app.wrongQuestions.length}문항',
                      color: scheme.errorContainer,
                      onColor: scheme.onErrorContainer,
                      onTap: () => _startSession(context, app.wrongQuestions, '오답노트'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _ActionButton(
                icon: Icons.star_rounded,
                label: '즐겨찾기',
                subtitle: '북마크한 ${app.bookmarkedQuestions.length}문항 복습하기',
                color: scheme.tertiaryContainer,
                onColor: scheme.onTertiaryContainer,
                wide: true,
                onTap: () => _startSession(context, app.bookmarkedQuestions, '즐겨찾기'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '카테고리별 학습',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Taller than a strict square so the card's icon + title +
                // subtitle + progress bar always fit, even with a larger
                // system font size (see CategoryCard bottom-overflow fix).
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cat = categories[i];
                  final stat = app.statFor(cat);
                  return CategoryCard(
                    stat: stat,
                    onTap: () => _startSession(
                      context,
                      app.questionsInCategory(cat),
                      cat,
                    ),
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSheet(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _themeTile(ctx, app, ThemeMode.system, '시스템 기본', Icons.smartphone_rounded),
              _themeTile(ctx, app, ThemeMode.light, '라이트 모드', Icons.light_mode_rounded),
              _themeTile(ctx, app, ThemeMode.dark, '다크 모드', Icons.dark_mode_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    AppState app,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final selected = app.themeMode == mode;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      onTap: () {
        app.setThemeMode(mode);
        Navigator.of(context).pop();
      },
    );
  }
}

class _HeroProgressCard extends StatelessWidget {
  const _HeroProgressCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: app.totalCount == 0 ? 0 : app.solvedCount / app.totalCount,
            color: Colors.white,
            label: '학습률',
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${app.solvedCount} / ${app.totalCount} 문항 학습',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '정답률 ${(app.overallAccuracy * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                Text(
                  app.solvedCount == 0
                      ? '오늘부터 시작해볼까요? 🐧'
                      : '꾸준히 잘하고 있어요!',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onColor,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: onColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: onColor.withValues(alpha: 0.8), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
