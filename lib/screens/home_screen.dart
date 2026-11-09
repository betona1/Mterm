import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../core/sfx.dart';
import '../data/progress.dart';
import '../game/quiz_engine.dart';
import '../game/quiz_screen.dart';
import 'dictionary_screen.dart';
import 'flashcard_screen.dart';
import 'list_study_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// 태블릿 판정: 짧은 변이 600dp 이상
bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;

/// 홈·사전·통계·설정. 폰은 하단 탭, 태블릿은 왼쪽 레일.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [HomeTab(), DictionaryScreen(), StatsScreen(), SettingsScreen()];
    if (isTablet(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              indicatorColor: AppTheme.mintSoft,
              leading: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(Mascot.face, width: 48, height: 48, fit: BoxFit.cover)),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('홈')),
                NavigationRailDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: Text('사전')),
                NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: Text('통계')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: Text('설정')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: _tab, children: pages)),
          ],
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.mintSoft,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: '사전'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: '통계'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: '설정'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  static const _tips = [
    '약어는 풀네임 철자와 같이 외우면 두 배로 오래 남아요!',
    '틀린 용어는 바로 다음 날 다시 나와요. 틀려도 괜찮아요.',
    '하루 목표를 채우면 연속 기록 🔥 이 이어져요.',
    '「완전 정복」은 철자·약어·뜻을 모두 맞혀야 해요. 하트 3개!',
    '「만점 도전」은 틀린 문제가 계속 다시 나와요. 전부 맞힐 때까지!',
    '「리스트업」으로 10개씩 쭉 보고 자동으로 넘기며 눈에 익혀요.',
    '설정에서 하드 모드를 켜면 뜻도 직접 입력해요.',
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.progress;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final cat = p.selectedCat;
        final pool = scope.repo.inCategory(cat);
        final catName = scope.repo.category(cat)?.name ?? '전체';
        final due = p.due(pool).length;
        final weak = p.weak(pool).length;
        final tip = p.goalReachedToday ? '오늘 목표 달성! 더 하면 보너스예요 🎉' : _tips[DateTime.now().day % _tips.length];
        final tablet = isTablet(context);

        final quickRow = (due > 0 || weak > 0)
            ? Row(
                children: [
                  if (due > 0)
                    Expanded(child: _SmallAction(emoji: '🔁', title: '복습 $due개', subtitle: '잊기 전에!', color: Guide.moa.color, onTap: () => _start(context, QuizMode.review))),
                  if (due > 0 && weak > 0) const SizedBox(width: 10),
                  if (weak > 0)
                    Expanded(child: _SmallAction(emoji: '🩹', title: '틀린 문제 $weak개', subtitle: '약한 용어 보강', color: AppTheme.wrong, onTap: () => _start(context, QuizMode.wrong))),
                ],
              )
            : const SizedBox.shrink();

        final modes = GridView.count(
          crossAxisCount: tablet ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: tablet ? 1.5 : 1.25,
          children: [
            _ModeCard(mode: QuizMode.meaning, color: AppTheme.primary, onTap: () => _start(context, QuizMode.meaning)),
            _ModeCard(mode: QuizMode.spelling, color: Guide.lingki.color, onTap: () => _start(context, QuizMode.spelling)),
            _ModeCard(mode: QuizMode.abbr, color: Guide.doolin.color, onTap: () => _start(context, QuizMode.abbr)),
            _ModeCard(mode: QuizMode.boss, color: AppTheme.pink, onTap: () => _start(context, QuizMode.boss)),
            _ModeCard(mode: QuizMode.mastery, color: Guide.shanling.color, onTap: () => _start(context, QuizMode.mastery)),
            _ModeCard(
              mode: QuizMode.flash,
              color: Guide.moa.color,
              onTap: () {
                SfxService.instance.play(Sfx.flip);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => FlashcardScreen(terms: pool, title: catName)));
              },
            ),
          ],
        );

        final listStudy = _WideAction(
          emoji: '📋',
          title: tablet ? '용어 리스트업 · 자동 암기 (태블릿 추천)' : '용어 리스트업 · 자동 암기',
          subtitle: '$catName ${pool.length}개 · 10개씩 쭉 보고 2분마다 자동으로 넘어가요',
          color: AppTheme.primary,
          onTap: () {
            SfxService.instance.play(Sfx.tap);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListStudyScreen(terms: pool, title: catName)));
          },
        );

        if (tablet) {
          // ── 태블릿: 왼쪽 마스코트·목표, 오른쪽 학습 ─────────────
          return SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 12, 24),
                    children: [
                      _Header(progress: p),
                      const SizedBox(height: 18),
                      Center(child: BobbingMascot(asset: Mascot.body, height: 300)),
                      const SizedBox(height: 10),
                      SpeechBubble(text: tip),
                      const SizedBox(height: 14),
                      _GoalCard(progress: p),
                      const SizedBox(height: 18),
                      _GuideStrip(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 16, 24, 24),
                    children: [
                      _CategoryPicker(selected: cat, onChanged: p.setCategory),
                      const SizedBox(height: 14),
                      listStudy,
                      const SizedBox(height: 12),
                      quickRow,
                      if (due > 0 || weak > 0) const SizedBox(height: 10),
                      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('게임으로 외우기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                      modes,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // ── 폰 ─────────────────────────────────────────────────
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _Header(progress: p),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const BobbingMascot(asset: Mascot.body, height: 190),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SpeechBubble(text: tip),
                        const SizedBox(height: 12),
                        _GoalCard(progress: p),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _CategoryPicker(selected: cat, onChanged: p.setCategory),
              const SizedBox(height: 14),
              listStudy,
              const SizedBox(height: 10),
              quickRow,
              if (due > 0 || weak > 0) const SizedBox(height: 10),
              modes,
              const SizedBox(height: 16),
              _GuideStrip(),
            ],
          ),
        );
      },
    );
  }

  static void _start(BuildContext context, QuizMode mode) {
    final scope = AppScope.of(context);
    final engine = QuizEngine(scope.repo, scope.progress);
    final s = engine.build(mode, cat: scope.progress.selectedCat);
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mode == QuizMode.abbr ? '이 분류에는 약어가 있는 용어가 없어요' : '풀 문제가 없어요. 먼저 다른 모드로 공부해 봐요!'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    SfxService.instance.play(Sfx.tap);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(session: s)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('메디텀', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: -0.5)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.mintSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text('Lv.${p.level}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(p.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: p.levelProgress, minHeight: 8, backgroundColor: AppTheme.mintSoft, color: AppTheme.star),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${p.xp} XP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.pink.withValues(alpha: 0.4))),
          child: Column(
            children: [
              Text('🔥 ${p.streak}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('연속일', style: TextStyle(fontSize: 11, color: AppTheme.inkSoft, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14))),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(value: p.goalProgress, strokeWidth: 7, backgroundColor: AppTheme.mintSoft, color: p.goalReachedToday ? AppTheme.star : AppTheme.primary, strokeCap: StrokeCap.round),
                Center(child: Text(p.goalReachedToday ? '✓' : '${(p.goalProgress * 100).round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('오늘 목표', style: TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w700)),
                Text('${min(p.todayCount, p.dailyGoal)} / ${p.dailyGoal}문제', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('정답 ${p.todayCorrect}개', style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});
  final String? selected;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('어떤 용어를 공부할까요?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CatChip(
                label: '전체',
                emoji: '🏥',
                color: AppTheme.primary,
                selected: selected == null,
                count: scope.repo.terms.length,
                mastered: p.masteredCount(scope.repo.terms),
                onTap: () => onChanged(null),
              ),
              for (final c in scope.repo.categories)
                _CatChip(
                  label: c.name,
                  emoji: c.emoji,
                  color: c.color,
                  face: Guide.byId(c.guide).face,
                  selected: selected == c.id,
                  count: scope.repo.inCategory(c.id).length,
                  mastered: p.masteredCount(scope.repo.inCategory(c.id)),
                  onTap: () => onChanged(c.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.emoji, required this.color, required this.selected, required this.count, required this.mastered, required this.onTap, this.face});
  final String label;
  final String emoji;
  final Color color;
  final String? face;
  final bool selected;
  final int count;
  final int mastered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SfxService.instance.play(Sfx.tap);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.25), width: selected ? 2 : 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (face != null)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                child: ClipOval(child: Image.asset(face!, fit: BoxFit.cover)),
              )
            else
              Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? color : AppTheme.ink)),
            Text('$mastered/$count', style: const TextStyle(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.color, required this.onTap});
  final QuizMode mode;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, color.withValues(alpha: 0.10)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.emoji, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              Text(mode.label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color.computeLuminance() > 0.6 ? AppTheme.ink : color)),
              const SizedBox(height: 2),
              Text(mode.desc, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.emoji, required this.title, required this.subtitle, required this.color, required this.onTap});
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideAction extends StatelessWidget {
  const _WideAction({required this.emoji, required this.title, required this.subtitle, required this.onTap, required this.color});
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            gradient: LinearGradient(colors: [Colors.white, color.withValues(alpha: 0.12)]),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// 병동 친구들 소개 띠
class _GuideStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('병동 친구들', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Guide.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final g = Guide.all[i];
              return Container(
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: g.color.withValues(alpha: 0.3))),
                child: Column(
                  children: [
                    GuideAvatar(g, size: 44),
                    const SizedBox(height: 6),
                    Text(g.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(g.role, style: const TextStyle(fontSize: 10, color: AppTheme.inkSoft, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
