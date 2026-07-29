import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum OptionVisualState { idle, selectedPending, correct, wrongSelected, wrongDim }

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String text;
  final OptionVisualState state;
  final VoidCallback? onTap;

  static const _labels = ['①', '②', '③', '④', '⑤'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    Color bg;
    Color border;
    Color fg;
    Widget? trailing;

    switch (state) {
      case OptionVisualState.idle:
        bg = scheme.surfaceContainerHigh;
        border = scheme.outlineVariant.withValues(alpha: 0.5);
        fg = scheme.onSurface;
        break;
      case OptionVisualState.correct:
        bg = AppTheme.correctBgFor(brightness);
        border = AppTheme.correct;
        fg = AppTheme.correct;
        trailing = const Icon(Icons.check_circle_rounded, color: AppTheme.correct);
        break;
      case OptionVisualState.wrongSelected:
        bg = AppTheme.wrongBgFor(brightness);
        border = AppTheme.wrong;
        fg = AppTheme.wrong;
        trailing = const Icon(Icons.cancel_rounded, color: AppTheme.wrong);
        break;
      case OptionVisualState.wrongDim:
        bg = scheme.surfaceContainerHigh.withValues(alpha: 0.5);
        border = Colors.transparent;
        fg = scheme.onSurfaceVariant.withValues(alpha: 0.6);
        break;
      case OptionVisualState.selectedPending:
        bg = scheme.primaryContainer;
        border = scheme.primary;
        fg = scheme.onPrimaryContainer;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  index < _labels.length ? _labels[index] : '${index + 1}.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 15.5, height: 1.35, color: fg),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
