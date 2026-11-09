import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_scope.dart';
import 'core/app_theme.dart';
import 'core/characters.dart';
import 'core/sfx.dart';
import 'core/update_check.dart';
import 'data/progress.dart';
import 'data/term_repo.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  runApp(const MedTermApp());
}

/// 용어 사전과 진행도를 읽은 뒤 앱을 띄운다.
/// ⚠️ AppScope 는 MaterialApp **바깥**에 둔다 — Navigator 로 띄운 화면(퀴즈·결과)도 AppScope 아래여야 한다.
class MedTermApp extends StatefulWidget {
  const MedTermApp({super.key});

  @override
  State<MedTermApp> createState() => _MedTermAppState();
}

class _MedTermAppState extends State<MedTermApp> {
  late final Future<(TermRepo, Progress)> _f = _load();

  Future<(TermRepo, Progress)> _load() async {
    final results = await Future.wait([TermRepo.load(), Progress.load()]);
    final repo = results[0] as TermRepo;
    final progress = results[1] as Progress;
    SfxService.instance.enabled = progress.sound;
    return (repo, progress);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _f,
      builder: (context, snap) {
        Widget home;
        if (snap.hasError) {
          home = Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('용어를 읽지 못했어요\n${snap.error}', textAlign: TextAlign.center))));
        } else if (!snap.hasData) {
          home = const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BobbingMascot(asset: Mascot.face, height: 140),
                  SizedBox(height: 12),
                  Text('리링이 차트를 준비하고 있어요…', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                ],
              ),
            ),
          );
        } else {
          home = const _UpdateGate(child: HomeShell());
        }
        final app = MaterialApp(
          title: '메디텀',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: home,
        );
        if (snap.hasData) {
          final (repo, progress) = snap.data!;
          return AppScope(repo: repo, progress: progress, child: app);
        }
        return app;
      },
    );
  }
}

/// 홈이 뜬 뒤 깃허브 릴리스에 새 버전이 있는지 한 번 본다
class _UpdateGate extends StatefulWidget {
  const _UpdateGate({required this.child});
  final Widget child;

  @override
  State<_UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<_UpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) UpdateCheck.run(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
