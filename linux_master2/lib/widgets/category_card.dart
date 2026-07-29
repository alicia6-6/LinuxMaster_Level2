import 'package:flutter/material.dart';
import '../state/app_state.dart';

const Map<String, IconData> categoryIcons = {
  '리눅스개요': Icons.info_outline_rounded,
  '라이선스배포판': Icons.gavel_rounded,
  '설치파티션': Icons.storage_rounded,
  '부팅부트로더': Icons.power_settings_new_rounded,
  '파일시스템': Icons.folder_copy_rounded,
  '사용자그룹관리': Icons.group_rounded,
  '파일디렉토리명령어': Icons.folder_rounded,
  '텍스트처리명령어': Icons.text_snippet_rounded,
  '리다이렉션파이프': Icons.compare_arrows_rounded,
  '셸환경변수': Icons.terminal_rounded,
  '네트워크명령어': Icons.lan_rounded,
  '시스템관리': Icons.settings_suggest_rounded,
  '기타': Icons.apps_rounded,
};

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.stat,
    required this.onTap,
  });

  final CategoryStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = categoryIcons[stat.category] ?? Icons.apps_rounded;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                stat.category,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${stat.solved}/${stat.total}문항',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: stat.progressRatio,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
