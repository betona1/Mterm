import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../core/sfx.dart';
import '../core/update_check.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.progress;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('설정')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('효과음', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('정답·오답·콤보 소리'),
                    value: p.sound,
                    onChanged: (v) {
                      p.setSound(v);
                      SfxService.instance.enabled = v;
                      if (v) SfxService.instance.play(Sfx.tap);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('글자 타일로 철자 입력', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('끄면 처음부터 키보드로 입력해요 (긴 용어는 항상 키보드)'),
                    value: p.tiles,
                    onChanged: p.setTiles,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('하드 모드 · 뜻 직접 입력', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('약어 정복·완전 정복에서 뜻을 보기 대신 한국어로 적어요 (+5 XP)'),
                    value: p.hardMeaning,
                    onChanged: p.setHardMeaning,
                  ),
                ],
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('하루 목표', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const Spacer(),
                        Text('${p.dailyGoal}문제', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 16)),
                      ],
                    ),
                    Slider(
                      value: p.dailyGoal.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: '${p.dailyGoal}',
                      onChanged: (v) => p.setDailyGoal(v.round()),
                    ),
                    const Text('목표를 채운 날이 이어지면 연속 기록 🔥 이 올라가요.', style: TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(Mascot.face, width: 48, height: 48, fit: BoxFit.cover)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('메디텀 1.0', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('용어 ${scope.repo.terms.length}개 · 분류 ${scope.repo.categories.length}개', style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '리링과 VAVELING 친구들이 간호사 용어를 게임처럼 외우게 도와줘요. '
                      '틀린 용어는 라이트너 간격 반복으로 1·2·4·7·15일 뒤에 다시 나와요.\n\n'
                      'PDF 용어집 추가: 컴퓨터의 data/pdf 폴더에 PDF 를 넣고 tools/pdf_to_terms.py 를 돌린 뒤 다시 빌드하면 돼요.',
                      style: TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w600, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 깃허브 릴리스에서 새 APK 확인 (안드로이드). 켤 때도 자동으로 확인한다.
            FutureBuilder<String>(
              future: UpdateCheck.currentVersion(),
              builder: (context, snap) => FilledButton.icon(
                onPressed: () async {
                  final m = ScaffoldMessenger.of(context);
                  m.showSnackBar(const SnackBar(content: Text('깃허브에서 새 버전을 확인하는 중…'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
                  final r = await UpdateCheck.run(context);
                  final msg = switch (r) {
                    UpdateResult.upToDate => '지금이 최신 버전이에요 ✅',
                    UpdateResult.shown => null,
                    UpdateResult.unsupported => '웹 버전은 새로고침하면 자동으로 최신이 돼요',
                    UpdateResult.failed => '확인하지 못했어요. 인터넷 연결이나 깃허브 릴리스를 확인해 주세요',
                  };
                  if (msg != null) {
                    m.hideCurrentSnackBar();
                    m.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
                  }
                },
                icon: const Icon(Icons.system_update_rounded),
                label: Text('업데이트 확인 (현재 ${snap.data ?? '…'})'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.wrong, side: const BorderSide(color: AppTheme.wrong, width: 1.4)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('학습 기록을 모두 지울까요?'),
                    content: const Text('경험치·연속 기록·암기 상태·배지가 모두 사라져요. 되돌릴 수 없어요.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.wrong), onPressed: () => Navigator.pop(c, true), child: const Text('지우기')),
                    ],
                  ),
                );
                if (ok == true) await p.reset();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('학습 기록 초기화'),
            ),
          ],
        ),
      ),
    );
  }
}
