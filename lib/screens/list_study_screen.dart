import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/sfx.dart';
import '../data/term.dart';
import '../game/quiz_engine.dart';
import '../game/quiz_screen.dart';

/// 용어 리스트업 · 자동 암기.
/// 한 화면에 여러 용어(기본 10개)를 쭉 보여 주고, 정한 시간(기본 2분)마다 다음 묶음으로 자동으로 넘어간다.
/// 태블릿(가로 700dp 이상)에서는 2~3열로 크게, 자동 넘김이 기본으로 켜진다.
/// 묶음을 다 본 뒤 「이 묶음 만점 도전」으로 바로 시험할 수 있다 — 틀리면 다시 나와 전부 맞힐 때까지.
class ListStudyScreen extends StatefulWidget {
  const ListStudyScreen({super.key, required this.terms, required this.title, this.autoStart});

  final List<Term> terms;
  final String title;

  /// null 이면 태블릿에서만 자동
  final bool? autoStart;

  @override
  State<ListStudyScreen> createState() => _ListStudyScreenState();
}

class _ListStudyScreenState extends State<ListStudyScreen> {
  static const pageSizes = [5, 10, 15, 20];
  static const intervals = [30, 60, 90, 120, 180, 300];

  late List<Term> _terms = [...widget.terms];
  int _pageSize = 10;
  int _interval = 120;
  int _page = 0;
  int _left = 120;
  bool _auto = false;
  bool _hideKo = false;
  bool _hideTerm = false;
  bool _shuffled = false;
  Timer? _timer;
  final _pager = PageController();

  int get _pages => (_terms.length / _pageSize).ceil().clamp(1, 1 << 20);

  List<Term> _pageTerms(int p) => _terms.skip(p * _pageSize).take(_pageSize).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wide = MediaQuery.sizeOf(context).shortestSide >= 600;
      final auto = widget.autoStart ?? wide;
      if (auto) _setAuto(true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pager.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _setAuto(bool v) {
    _timer?.cancel();
    setState(() {
      _auto = v;
      _left = _interval;
    });
    if (v) {
      WakelockPlus.enable();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left <= 1) {
          _goNext(auto: true);
        } else {
          setState(() => _left--);
          if (_left == 3) SfxService.instance.play(Sfx.tick);
        }
      });
    } else {
      WakelockPlus.disable();
    }
  }

  void _goNext({bool auto = false}) {
    if (_page + 1 >= _pages) {
      // 한 바퀴 끝: 자동이면 처음부터 다시, 소리로 알린다
      SfxService.instance.play(Sfx.complete);
      if (auto) {
        _jump(0);
        return;
      }
      _setAuto(false);
      _askQuiz(all: true);
      return;
    }
    if (!auto) SfxService.instance.play(Sfx.flip);
    _jump(_page + 1);
  }

  void _jump(int p) {
    _pager.animateToPage(p, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    setState(() {
      _page = p;
      _left = _interval;
    });
  }

  void _askQuiz({bool all = false}) {
    final pool = all ? _terms : _pageTerms(_page);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(all ? '한 바퀴 다 봤어요!' : '이 묶음으로 시험 볼까요?'),
        content: Text('${pool.length}개 용어로 만점 도전을 해요.\n틀린 건 다시 나와서 전부 맞힐 때까지 계속돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('더 볼래요')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              _startQuiz(pool);
            },
            child: const Text('🎯 만점 도전'),
          ),
        ],
      ),
    );
  }

  void _startQuiz(List<Term> pool) {
    final scope = AppScope.of(context);
    final wasAuto = _auto;
    if (wasAuto) _setAuto(false);
    final s = QuizEngine(scope.repo, scope.progress).build(QuizMode.mastery, customPool: pool, count: pool.length);
    if (s == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(session: s))).then((_) {
      if (mounted && wasAuto) _setAuto(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1100 ? 3 : (width >= 700 ? 2 : 1);
    final wide = width >= 700;
    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('리스트업 · ${widget.title}'),
        actions: [
          IconButton(
            tooltip: '섞기',
            icon: Icon(_shuffled ? Icons.shuffle_on_rounded : Icons.shuffle_rounded),
            onPressed: () => setState(() {
              _shuffled = !_shuffled;
              _terms = _shuffled ? ([...widget.terms]..shuffle()) : [...widget.terms];
              _page = 0;
              _left = _interval;
              _pager.jumpToPage(0);
            }),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: '묶음 크기·간격',
            onSelected: (v) {
              final parts = v.split(':');
              setState(() {
                if (parts[0] == 'n') {
                  _pageSize = int.parse(parts[1]);
                  _page = 0;
                  _pager.jumpToPage(0);
                } else {
                  _interval = int.parse(parts[1]);
                }
                _left = _interval;
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(enabled: false, child: Text('한 화면 용어 수', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              for (final n in pageSizes) CheckedPopupMenuItem(value: 'n:$n', checked: _pageSize == n, child: Text('$n개')),
              const PopupMenuDivider(),
              const PopupMenuItem(enabled: false, child: Text('자동 넘김 간격', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              for (final s in intervals)
                CheckedPopupMenuItem(value: 't:$s', checked: _interval == s, child: Text(s >= 60 ? '${s ~/ 60}분${s % 60 == 0 ? '' : ' ${s % 60}초'}' : '$s초')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 줄: 묶음 번호 · 남은 시간 · 가리기 토글
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Text('${_page + 1} / $_pages 묶음', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(width: 10),
                if (_auto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.mintSoft, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('$mm:$ss 뒤 다음', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary, fontSize: 13)),
                      ],
                    ),
                  ),
                const Spacer(),
                _Toggle(label: '뜻 가리기', on: _hideKo, onTap: () => setState(() => _hideKo = !_hideKo)),
                const SizedBox(width: 6),
                _Toggle(label: '용어 가리기', on: _hideTerm, onTap: () => setState(() => _hideTerm = !_hideTerm)),
              ],
            ),
          ),
          if (_auto)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: 1 - _left / _interval, minHeight: 6, backgroundColor: AppTheme.mintSoft, color: AppTheme.pink),
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pager,
              itemCount: _pages,
              onPageChanged: (p) {
                if (p != _page) {
                  setState(() {
                    _page = p;
                    _left = _interval;
                  });
                }
              },
              itemBuilder: (_, p) {
                final items = _pageTerms(p);
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, wide ? 16 : 10),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: wide ? 96 : 84,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _TermRow(term: items[i], index: p * _pageSize + i + 1, hideKo: _hideKo, hideTerm: _hideTerm, large: wide),
                );
              },
            ),
          ),
          // 아래 조작 줄
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _page > 0 ? () => _jump(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: '이전 묶음',
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _setAuto(!_auto),
                      style: FilledButton.styleFrom(backgroundColor: _auto ? AppTheme.pink : AppTheme.primary),
                      icon: Icon(_auto ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      label: Text(_auto ? '자동 넘김 멈춤' : '자동 넘김 시작'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: () => _goNext(),
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: '다음 묶음',
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => _askQuiz(),
                    icon: const Text('🎯'),
                    label: Text(wide ? '이 묶음 만점 도전' : '시험'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SfxService.instance.play(Sfx.tap);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? AppTheme.pinkSoft : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppTheme.pink : AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 14, color: on ? AppTheme.pink : AppTheme.inkSoft),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? AppTheme.pink : AppTheme.ink)),
          ],
        ),
      ),
    );
  }
}

/// 용어 한 줄: 번호 · 약어 · 영어 · 뜻 (가리기 가능, 탭하면 그 줄만 잠깐 보임)
class _TermRow extends StatefulWidget {
  const _TermRow({required this.term, required this.index, required this.hideKo, required this.hideTerm, required this.large});
  final Term term;
  final int index;
  final bool hideKo;
  final bool hideTerm;
  final bool large;

  @override
  State<_TermRow> createState() => _TermRowState();
}

class _TermRowState extends State<_TermRow> {
  bool _peek = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.term;
    final cat = AppScope.of(context).repo.category(t.cat);
    final color = cat?.color ?? AppTheme.primary;
    final big = widget.large ? 22.0 : 18.0;
    final showKo = !widget.hideKo || _peek;
    final showTerm = !widget.hideTerm || _peek;
    return GestureDetector(
      onTapDown: (_) => setState(() => _peek = true),
      onTapUp: (_) => setState(() => _peek = false),
      onTapCancel: () => setState(() => _peek = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Text('${widget.index}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: widget.large ? 84 : 64,
              child: t.hasAbbr
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(8)),
                      child: Text(t.abbr, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: widget.large ? 15 : 13)),
                    )
                  : Text(cat?.emoji ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _maybeHidden(showTerm, Text(t.termDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: big, fontWeight: FontWeight.w800, height: 1.15))),
                  const SizedBox(height: 2),
                  _maybeHidden(showKo, Text(t.ko, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: big - 4, fontWeight: FontWeight.w600, color: AppTheme.inkSoft))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _maybeHidden(bool show, Widget child) {
    if (show) return child;
    return Container(
      height: 18,
      width: 140,
      decoration: BoxDecoration(color: AppTheme.mintSoft, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 6),
      child: const Text('눌러서 보기', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w700)),
    );
  }
}
