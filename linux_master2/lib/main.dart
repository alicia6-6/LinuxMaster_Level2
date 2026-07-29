import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LinuxMasterApp());
}

class LinuxMasterApp extends StatelessWidget {
  const LinuxMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: '리눅스마스터 2급 암기장',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appState.themeMode,
          // Clamp system font scaling so fixed-height layouts (category grid
          // cards, option tiles) can't be pushed into a bottom overflow by a
          // large accessibility text size setting.
          builder: (context, child) {
            final clamped = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: clamped),
              child: child!,
            );
          },
          home: const _AppRoot(),
        ),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AppState, bool>((s) => s.loading);
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const HomeScreen();
  }
}
