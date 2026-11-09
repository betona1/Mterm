import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../core/sfx.dart';
import '../data/term.dart';

/// 카드 넘기며 보기. 앞면: 용어+약어, 뒷면: 뜻. 「알아요/모르겠어요」로 가볍게 기록.
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key, required this.terms, required this.title});

  final List<Term> terms;
  final String title;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late final List<Term> _cards = [...widget.terms]..shuffle();
  final _page = PageController();
  int _index = 0;
  bool _flipped = false;
  bool _koFront = false;
  int _known = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _mark(bool known) {
    final p = AppScope.of(context).progress;
    p.record(_cards[_index].id, known, baseXp: 3);
    SfxService.instance.play(known ? Sfx.match : Sfx.tick);
    if (known) _known++;
    if (_index + 1 >= _cards.length) {
      SfxService.instance.play(Sfx.complete);
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('카드 끝!'),
          content: Text('${_cards.length}장 중 $_known장을 알고 있었어요.\n모르는 건 복습 목록에 들어갔어요.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    _page.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('플래시카드 · ${widget.title}'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _koFront = !_koFront;
              _flipped = false;
            }),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(_koFront ? '뜻 → 용어' : '용어 → 뜻'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: (_index + 1) / _cards.length, minHeight: 8, backgroundColor: AppTheme.mintSoft, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${_index + 1}/${_cards.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _cards.length,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _flipped = false;
                }),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: _FlipCard(
                    term: _cards[i],
                    flipped: i == _index && _flipped,
                    koFront: _koFront,
                    onTap: () {
                      SfxService.instance.play(Sfx.flip);
                      setState(() => _flipped = !_flipped);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mark(false),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.wrong, side: const BorderSide(color: AppTheme.wrong, width: 1.6)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('모르겠어요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mark(true),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.correct),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('알아요'),
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

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.term, required this.flipped, required this.koFront, required this.onTap});
  final Term term;
  final bool flipped;
  final bool koFront;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = AppScope.of(context).repo.category(term.cat);
    final color = cat?.color ?? AppTheme.primary;
    final showKo = koFront != flipped;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: flipped ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (_, v, _) {
          final angle = v * pi;
          final isBack = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(isBack ? pi : 0),
              child: Container(
                decoration: BoxDecoration(
                  color: isBack ? color.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cat != null) Text('${cat.emoji} ${cat.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                    const Spacer(),
                    if (showKo) ...[
                      Text(term.ko, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.3)),
                    ] else ...[
                      if (term.hasAbbr)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(14)),
                          child: Text(term.abbr, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      Text(term.termDisplay, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.25)),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                          child: ClipOval(child: Image.asset(Mascot.face, fit: BoxFit.cover)),
                        ),
                        const SizedBox(width: 8),
                        Text(flipped ? '카드를 눌러 돌아가기' : '카드를 눌러 뒤집기', style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
