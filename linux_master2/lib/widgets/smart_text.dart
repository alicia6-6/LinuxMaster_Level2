import 'package:flutter/material.dart';

/// Renders multi-line question/explanation text, giving lines that look like
/// shell commands or file paths a distinct monospace "terminal" treatment so
/// command syntax stands out from prose.
class SmartText extends StatelessWidget {
  const SmartText(
    this.text, {
    super.key,
    this.style,
    this.codeStyle,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? codeStyle;

  static final RegExp _codeHint = RegExp(
    r'^[#\$\[].*|.*[@~].*|^[a-zA-Z_./\-]+\s*[\-\[].*|^\s*[①②③④⑤].*',
  );

  bool _looksLikeCode(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    final koreanChars = RegExp(r'[가-힣]').allMatches(trimmed).length;
    final ratio = koreanChars / trimmed.length;
    if (ratio > 0.35) return false;
    if (trimmed.startsWith('#') ||
        trimmed.startsWith('\$') ||
        trimmed.startsWith('[') ||
        trimmed.contains('@') ||
        trimmed.contains('/etc/') ||
        trimmed.contains('/dev/') ||
        trimmed.contains('->')) {
      return true;
    }
    return _codeHint.hasMatch(trimmed) && ratio < 0.2;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    final scheme = Theme.of(context).colorScheme;
    final mono = codeStyle ??
        baseStyle?.copyWith(
          fontFamily: 'monospace',
          fontSize: (baseStyle.fontSize ?? 15) - 1,
          color: scheme.onSurfaceVariant,
        );

    final lines = text.split('\n');
    final widgets = <Widget>[];
    List<String>? codeBuffer;

    void flushCode() {
      if (codeBuffer == null || codeBuffer!.isEmpty) return;
      widgets.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: SelectableText(codeBuffer!.join('\n'), style: mono),
      ));
      codeBuffer = null;
    }

    for (final line in lines) {
      if (_looksLikeCode(line)) {
        (codeBuffer ??= []).add(line);
      } else {
        flushCode();
        if (line.trim().isEmpty) {
          widgets.add(const SizedBox(height: 6));
        } else {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(line, style: baseStyle),
          ));
        }
      }
    }
    flushCode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
