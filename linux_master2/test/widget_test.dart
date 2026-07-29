// Basic smoke test: the app boots, shows the loading spinner, then renders
// the home screen with its title once question data has loaded.
//
// Loading the question bank goes through real file I/O (rootBundle reads the
// JSON asset from disk in the test harness), so the wait has to happen
// inside tester.runAsync() — otherwise it hangs forever inside flutter
// test's fake-async zone, which doesn't advance real I/O on its own.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linux_master2/main.dart';

void main() {
  testWidgets('App boots and shows home screen title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LinuxMasterApp());

    // Initially shows a loading spinner while the JSON asset + prefs load.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump();

    // SliverAppBar.large renders both an expanded and a collapsed title,
    // so this legitimately appears twice in the tree.
    expect(find.text('리눅스마스터 2급 암기장'), findsAtLeastNWidgets(1));
    expect(find.text('전체 학습'), findsOneWidget);
  });
}
