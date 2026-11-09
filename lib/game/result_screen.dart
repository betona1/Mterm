import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../core/sfx.dart';
import '../data/progress.dart';
import 'quiz_engine.dart';
import 'quiz_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.session});

  final QuizSession session;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    final s = widget.session;
    SfxService.instance.play(s.perfect ? Sfx.fanfare : Sfx.complete);
  }

  String get _headline {
    final s = widget.session;
    if (s.hearts == 0) return '하트가 다 떨어졌어요…';
    if (s.mode.requeueWrong) return s.retries == 0 ? '한 번에 만점! 완벽해요 💯' : '🎯 전부 정복했어요! 만점!';
    final r = s.results.isEmpty ? 0.0 : s.correctCount / s.results.length;
    if (s.perfect) return '퍼펙트! 완벽해요 💯';
    if (r >= 0.8) return '훌륭해요! 거의 다 외웠어요';
    if (r >= 0.5) return '잘하고 있어요, 조금만 더!';
    return '괜찮아요, 틀린 건 다시 나와요';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final p = AppScope.of(context).progress;
    final total = s.results.length;
    final acc = total == 0 ? 0 : (s.correctCount * 100 / total).round();
    final wrong = s.wrongTerms;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  Center(child: BobbingMascot(asset: Mascot.face, height: 150)),
                  const SizedBox(height: 8),
                  Text(_headline, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${s.mode.emoji} ${s.mode.label}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (s.mode.requeueWrong)
                        _Stat(label: '정복한 용어', value: '${s.baseCount}', color: AppTheme.correct)
                      else
                        _Stat(label: '정답', value: '${s.correctCount}/$total', color: AppTheme.correct),
                      const SizedBox(width: 10),
                      if (s.mode.requeueWrong)
                        _Stat(label: '재도전', value: '${s.retries}회', color: AppTheme.primary)
                      else
                        _Stat(label: '정확도', value: '$acc%', color: AppTheme.primary),
                      const SizedBox(width: 10),
                      _Stat(label: '최대 콤보', value: '${s.maxCombo}', color: AppTheme.pink),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.star),
                          const SizedBox(width: 10),
                          Text('+${s.xpEarned} XP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('Lv.${p.level} ${p.title}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                        ],
                      ),
                    ),
                  ),
                  if (s.leveledUp)
                    _Banner(color: AppTheme.star, icon: Icons.emoji_events, text: '레벨 업! 이제 「${p.title}」예요'),
                  for (final b in s.newBadges)
                    if (StudyBadge.byId(b) case final badge?)
                      _Banner(color: AppTheme.pink, icon: Icons.military_tech, text: '새 배지 ${badge.emoji} ${badge.name} — ${badge.desc}'),
                  if (wrong.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(s.mode.requeueWrong ? '헷갈렸던 용어 ${wrong.length}개' : '다시 볼 용어 ${wrong.length}개', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (final t in wrong)
                      Card(
                        child: ListTile(
                          leading: t.hasAbbr
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(8)),
                                  child: Text(t.abbr, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
                                )
                              : const Icon(Icons.bookmark_border, color: AppTheme.inkSoft),
                          title: Text(t.term, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(t.ko),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('홈으로'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final scope = AppScope.of(context);
                        final engine = QuizEngine(scope.repo, scope.progress);
                        final next = wrong.isNotEmpty
                            ? engine.build(QuizMode.wrong, cat: s.categoryId, customPool: wrong, count: wrong.length)
                            : engine.build(s.mode, cat: s.categoryId);
                        if (next == null) {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          return;
                        }
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => QuizScreen(session: next)));
                      },
                      child: Text(wrong.isNotEmpty ? '틀린 것만 다시' : '한 판 더'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
