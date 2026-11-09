import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mterm/core/app_scope.dart';
import 'package:mterm/core/app_theme.dart';
import 'package:mterm/data/progress.dart';
import 'package:mterm/data/term_repo.dart';
import 'package:mterm/game/quiz_engine.dart';
import 'package:mterm/screens/home_screen.dart';
import 'package:mterm/screens/list_study_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 폰·태블릿 크기에서 홈과 리스트업이 오류(overflow 등) 없이 그려지는지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(TermRepo, Progress)> load() async {
    SharedPreferences.setMockInitialValues({});
    return (await TermRepo.load(), await Progress.load());
  }

  Future<void> pumpApp(WidgetTester tester, Size size, Widget home) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    // ⚠️ 에셋 읽기(rootBundle)는 실제 I/O 라 FakeAsync 안에서는 끝나지 않는다 → runAsync
    final (repo, progress) = (await tester.runAsync(load))!;
    await tester.pumpWidget(AppScope(repo: repo, progress: progress, child: MaterialApp(theme: AppTheme.light(), home: home)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('폰 홈: 하단 탭, 모드 카드 6개', (tester) async {
    await pumpApp(tester, const Size(390, 844), const HomeShell());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('만점 도전'), findsOneWidget);
    expect(find.textContaining('리스트업'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('태블릿 홈: 왼쪽 레일 2단 구성', (tester) async {
    await pumpApp(tester, const Size(1280, 800), const HomeShell());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('게임으로 외우기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('리스트업: 10개씩 묶음, 태블릿은 자동 넘김 켜짐', (tester) async {
    final (repo, _) = (await tester.runAsync(load))!;
    await pumpApp(tester, const Size(1280, 800), ListStudyScreen(terms: repo.terms.take(25).toList(), title: '테스트'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1 / 3 묶음'), findsOneWidget);
    expect(find.text('자동 넘김 멈춤'), findsOneWidget); // 태블릿 → 자동
    // 1초 지나면 카운트다운이 줄어든다
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('1:5'), findsOneWidget);
    // 다음 묶음
    await tester.tap(find.byTooltip('다음 묶음'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 / 3 묶음'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 타이머 정리
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('리스트업: 폰은 자동 넘김 꺼짐', (tester) async {
    final (repo, _) = (await tester.runAsync(load))!;
    await pumpApp(tester, const Size(390, 844), ListStudyScreen(terms: repo.terms.take(12).toList(), title: '테스트'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('자동 넘김 시작'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('만점 도전: 틀린 문제는 같은 유형으로 다시 만들어진다', () async {
    final (repo, progress) = await load();
    final engine = QuizEngine(repo, progress);
    final s = engine.build(QuizMode.mastery, count: 5)!;
    expect(s.questions.length, 5);
    expect(s.mode.requeueWrong, isTrue);
    final q = s.questions.first;
    final r = engine.retryOf(q);
    expect(r.term.id, q.term.id);
    expect(r.type, q.type);
    expect(r.retry, isTrue);
    if (q.choices.isNotEmpty) expect(r.choices[r.answer], q.choices[q.answer]);
  });
}
