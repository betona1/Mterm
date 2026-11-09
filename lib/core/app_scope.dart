import 'package:flutter/widgets.dart';

import '../data/progress.dart';
import '../data/term_repo.dart';

/// 앱 어디서나 용어 사전과 진행도를 꺼내 쓴다: `AppScope.of(context).repo`
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.repo, required this.progress, required super.child});

  final TermRepo repo;
  final Progress progress;

  static AppScope of(BuildContext context) {
    // repo·progress 는 앱 수명 내내 같으므로 의존 등록 없이 꺼낸다 (initState 에서도 안전)
    final s = context.getInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope 가 위에 없다');
    return s!;
  }

  @override
  bool updateShouldNotify(AppScope old) => repo != old.repo || progress != old.progress;
}
