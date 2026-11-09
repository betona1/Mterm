import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../data/progress.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.progress;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final all = scope.repo.terms;
        final mastered = p.masteredCount(all);
        final seen = p.seenCount(all);
        final acc = p.totalAnswered == 0 ? 0 : (p.totalCorrect * 100 / p.totalAnswered).round();
        final days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
        final counts = [for (final d in days) p.history[Progress.dayKey(d)] ?? 0];
        final maxC = max(1, counts.reduce(max));
        const wd = ['월', '화', '수', '목', '금', '토', '일'];

        return Scaffold(
          appBar: AppBar(title: const Text('학습 통계')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              // 레벨 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.mint, AppTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), color: Colors.white),
                      child: ClipOval(child: Image.asset(Mascot.face, fit: BoxFit.cover)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lv.${p.level} ${p.title}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: p.levelProgress, minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.35), color: AppTheme.star),
                          ),
                          const SizedBox(height: 4),
                          Text('${p.xp} XP · 다음 레벨까지 ${p.xpToNext} XP', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Tile(label: '암기 완료', value: '$mastered', unit: '/ ${all.length}', color: AppTheme.correct),
                  const SizedBox(width: 10),
                  _Tile(label: '만난 용어', value: '$seen', unit: '개', color: AppTheme.primary),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Tile(label: '정확도', value: '$acc', unit: '%', color: Guide.lingki.color),
                  const SizedBox(width: 10),
                  _Tile(label: '최고 콤보', value: '${p.bestCombo}', unit: '연속', color: AppTheme.pink),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Tile(label: '연속 달성', value: '${p.streak}', unit: '일', color: const Color(0xFFF08C6C)),
                  const SizedBox(width: 10),
                  _Tile(label: '푼 문제', value: '${p.totalAnswered}', unit: '개', color: Guide.moa.color),
                ],
              ),
              const SizedBox(height: 20),
              const Text('최근 7일', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Container(
                height: 150,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${counts[i]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: 8 + 80 * counts[i] / maxC,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: counts[i] >= p.dailyGoal ? AppTheme.star : (counts[i] > 0 ? AppTheme.primary : AppTheme.mintSoft),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(wd[days[i].weekday - 1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == 6 ? AppTheme.primary : AppTheme.inkSoft)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('분류별 암기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final c in scope.repo.categories)
                Builder(builder: (_) {
                  final pool = scope.repo.inCategory(c.id);
                  final m = p.masteredCount(pool);
                  final s = p.seenCount(pool);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        GuideAvatar(Guide.byId(c.guide), size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${c.emoji} ${c.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const Spacer(),
                                  Text('$m / ${pool.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    LinearProgressIndicator(value: pool.isEmpty ? 0 : s / pool.length, minHeight: 9, backgroundColor: AppTheme.mintSoft, color: c.color.withValues(alpha: 0.3)),
                                    LinearProgressIndicator(value: pool.isEmpty ? 0 : m / pool.length, minHeight: 9, backgroundColor: Colors.transparent, color: c.color),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 14),
              const Text('배지', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: [
                  for (final b in StudyBadge.all)
                    Builder(builder: (_) {
                      final got = p.badges.contains(b.id);
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: got ? AppTheme.star.withValues(alpha: 0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: got ? AppTheme.star : AppTheme.primary.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Opacity(opacity: got ? 1 : 0.3, child: Text(b.emoji, style: const TextStyle(fontSize: 28))),
                            const SizedBox(height: 4),
                            Text(b.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: got ? AppTheme.ink : AppTheme.inkSoft)),
                            Text(b.desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w600), maxLines: 2),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.unit, required this.color});
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
