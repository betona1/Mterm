import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../core/sfx.dart';
import '../data/term.dart';
import '../game/quiz_engine.dart';
import '../game/quiz_screen.dart';
import 'flashcard_screen.dart';

/// 용어 사전: 검색 · 분류 · 즐겨찾기 · 암기 상태
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

enum _Filter { all, fav, abbr, weak, mastered }

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _q = TextEditingController();
  String? _cat;
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.progress;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        var list = scope.repo.search(_q.text);
        if (_cat != null) list = list.where((t) => t.cat == _cat).toList();
        list = switch (_filter) {
          _Filter.all => list,
          _Filter.fav => list.where((t) => p.peek(t.id)?.fav ?? false).toList(),
          _Filter.abbr => list.where((t) => t.hasAbbr).toList(),
          _Filter.weak => list.where((t) => p.peek(t.id)?.isWeak ?? false).toList(),
          _Filter.mastered => list.where((t) => p.peek(t.id)?.mastered ?? false).toList(),
        };
        return Scaffold(
          appBar: AppBar(
            title: Text('용어 사전 (${scope.repo.terms.length})'),
            actions: [
              if (list.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.primary),
                  tooltip: '이 목록으로 공부',
                  onSelected: (v) {
                    if (v == 'flash') {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FlashcardScreen(terms: list, title: '검색 결과')));
                      return;
                    }
                    final mode = v == 'spell' ? QuizMode.spelling : QuizMode.meaning;
                    final s = QuizEngine(scope.repo, p).build(mode, customPool: list, count: list.length.clamp(1, 15));
                    if (s != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(session: s)));
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'flash', child: Text('🃏 이 목록 플래시카드')),
                    PopupMenuItem(value: 'meaning', child: Text('🧩 이 목록 뜻 맞추기')),
                    PopupMenuItem(value: 'spell', child: Text('✏️ 이 목록 스펠링')),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '용어 · 약어 · 뜻 검색',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _q.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _q.clear();
                              setState(() {});
                            }),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip('전체', _filter == _Filter.all, () => setState(() => _filter = _Filter.all)),
                    _chip('⭐ 즐겨찾기', _filter == _Filter.fav, () => setState(() => _filter = _Filter.fav)),
                    _chip('약어만', _filter == _Filter.abbr, () => setState(() => _filter = _Filter.abbr)),
                    _chip('🩹 약한 용어', _filter == _Filter.weak, () => setState(() => _filter = _Filter.weak)),
                    _chip('✅ 암기 완료', _filter == _Filter.mastered, () => setState(() => _filter = _Filter.mastered)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip('모든 분류', _cat == null, () => setState(() => _cat = null)),
                    for (final c in scope.repo.categories) _chip('${c.emoji} ${c.name}', _cat == c.id, () => setState(() => _cat = c.id), color: c.color),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('해당하는 용어가 없어요', style: TextStyle(color: AppTheme.inkSoft, fontWeight: FontWeight.w600)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _TermTile(term: list[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          SfxService.instance.play(Sfx.tap);
          onTap();
        },
        selectedColor: c.withValues(alpha: 0.18),
        side: BorderSide(color: selected ? c : c.withValues(alpha: 0.25)),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? c : AppTheme.ink),
      ),
    );
  }
}

class _TermTile extends StatelessWidget {
  const _TermTile({required this.term});
  final Term term;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.progress;
    final st = p.peek(term.id);
    final cat = scope.repo.category(term.cat);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showDetail(context, term),
        leading: SizedBox(
          width: 56,
          child: Center(
            child: term.hasAbbr
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(term.abbr, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  )
                : Text(cat?.emoji ?? '•', style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(term.term, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        subtitle: Row(
          children: [
            Expanded(child: Text(term.ko, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            _MasteryDots(box: st?.box ?? 0, seen: st?.seen ?? false),
          ],
        ),
        trailing: IconButton(
          icon: Icon(st?.fav ?? false ? Icons.star_rounded : Icons.star_border_rounded, color: st?.fav ?? false ? AppTheme.star : AppTheme.inkSoft),
          onPressed: () {
            SfxService.instance.play(Sfx.tap);
            p.toggleFav(term.id);
          },
        ),
      ),
    );
  }

  static void _showDetail(BuildContext context, Term term) {
    final scope = AppScope.of(context);
    final cat = scope.repo.category(term.cat);
    final guide = Guide.byId(cat?.guide);
    final st = scope.progress.peek(term.id);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GuideAvatar(guide, size: 44),
                const SizedBox(width: 10),
                Expanded(child: SpeechBubble(text: '${cat?.name ?? ''} 용어예요. ${guide.subject} 함께 외워 줄게요!')),
              ],
            ),
            const SizedBox(height: 18),
            if (term.hasAbbr)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(14)),
                child: Text(term.allAbbrs.join(' / '), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            Text(term.termDisplay, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 6),
            Text(term.ko, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.inkSoft)),
            const SizedBox(height: 14),
            Row(
              children: [
                _MasteryDots(box: st?.box ?? 0, seen: st?.seen ?? false, size: 12),
                const SizedBox(width: 8),
                Text(
                  st == null || !st.seen ? '아직 안 풀어 봤어요' : '정답 ${st.correct} · 오답 ${st.wrong}${st.mastered ? ' · 암기 완료 ✅' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      final s = QuizEngine(scope.repo, scope.progress).build(QuizMode.spelling, customPool: [term], count: 1);
                      if (s != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(session: s)));
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('철자 연습'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      final pool = scope.repo.inCategory(term.cat);
                      final s = QuizEngine(scope.repo, scope.progress).build(QuizMode.meaning, cat: term.cat, customPool: pool);
                      if (s != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(session: s)));
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('${cat?.name ?? '분류'} 퀴즈'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 암기 단계 점 5개
class _MasteryDots extends StatelessWidget {
  const _MasteryDots({required this.box, required this.seen, this.size = 8});
  final int box;
  final bool seen;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(right: size * 0.3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= box ? (box >= 4 ? AppTheme.correct : AppTheme.primary) : (seen ? AppTheme.mintSoft : const Color(0xFFEDEFF2)),
            ),
          ),
      ],
    );
  }
}
