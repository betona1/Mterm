import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/sfx.dart';

/// 글자 타일 철자 입력. 공백·하이픈·숫자·기호는 자리에 고정되고 알파벳만 채운다.
/// 모두 채우면 [onComplete] 가 불린다. 힌트는 다음 빈 칸에 정답 글자를 놓는다.
class LetterTiles extends StatefulWidget {
  const LetterTiles({super.key, required this.answer, required this.onComplete, this.distractors = 2, this.enabled = true});

  final String answer;
  final void Function(String input) onComplete;
  final int distractors;
  final bool enabled;

  @override
  State<LetterTiles> createState() => LetterTilesState();
}

class _Tile {
  _Tile(this.id, this.ch);
  final int id;
  final String ch;
}

class LetterTilesState extends State<LetterTiles> {
  late final List<String?> _fixed; // 고정 글자(공백 등) 또는 null(채울 칸)
  late final List<_Tile?> _slots; // 채운 타일
  late final List<_Tile> _pool;
  final Set<int> _used = {};
  bool _done = false;
  int hintsUsed = 0;

  static const _alpha = 'abcdefghijklmnopqrstuvwxyz';

  @override
  void initState() {
    super.initState();
    final a = widget.answer;
    _fixed = [for (final r in a.runes) _isLetter(r) ? null : String.fromCharCode(r)];
    _slots = List<_Tile?>.filled(a.length, null);
    final letters = [for (final r in a.runes) if (_isLetter(r)) String.fromCharCode(r).toLowerCase()];
    final rnd = Random();
    final extra = <String>[];
    while (extra.length < widget.distractors) {
      final c = _alpha[rnd.nextInt(26)];
      extra.add(c);
    }
    final all = [...letters, ...extra]..shuffle(rnd);
    _pool = [for (var i = 0; i < all.length; i++) _Tile(i, all[i])];
  }

  static bool _isLetter(int r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122);

  int? get _nextEmpty {
    for (var i = 0; i < _slots.length; i++) {
      if (_fixed[i] == null && _slots[i] == null) return i;
    }
    return null;
  }

  String get current {
    final b = StringBuffer();
    for (var i = 0; i < _slots.length; i++) {
      b.write(_fixed[i] ?? _slots[i]?.ch ?? '_');
    }
    return b.toString();
  }

  void _place(_Tile t) {
    if (!widget.enabled || _done) return;
    final i = _nextEmpty;
    if (i == null) return;
    SfxService.instance.play(Sfx.tap);
    setState(() {
      _slots[i] = t;
      _used.add(t.id);
    });
    _checkDone();
  }

  void _remove(int i) {
    if (!widget.enabled || _done) return;
    final t = _slots[i];
    if (t == null) return;
    SfxService.instance.play(Sfx.tap);
    setState(() {
      _slots[i] = null;
      _used.remove(t.id);
    });
  }

  void _checkDone() {
    if (_nextEmpty != null) return;
    _done = true;
    widget.onComplete(current);
  }

  /// 틀리게 놓인 칸을 비우고, 다음 빈 칸에 정답 글자를 놓는다
  void hint() {
    if (!widget.enabled || _done) return;
    setState(() {
      hintsUsed++;
      for (var i = 0; i < _slots.length; i++) {
        final t = _slots[i];
        if (t != null && t.ch != widget.answer[i].toLowerCase()) {
          _slots[i] = null;
          _used.remove(t.id);
        }
      }
      final i = _nextEmpty;
      if (i == null) return;
      final need = widget.answer[i].toLowerCase();
      _Tile? t;
      for (final p in _pool) {
        if (!_used.contains(p.id) && p.ch == need) {
          t = p;
          break;
        }
      }
      if (t != null) {
        _slots[i] = t;
        _used.add(t.id);
      }
    });
    _checkDone();
  }

  /// 모두 지우기
  void clear() {
    if (_done) return;
    setState(() {
      for (var i = 0; i < _slots.length; i++) {
        _slots[i] = null;
      }
      _used.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 40;
    final n = _slots.length;
    // 글자가 많으면 칸을 줄인다
    final slotW = (width / max(n, 1)).clamp(22.0, 36.0);
    final slotH = slotW * 1.25;
    final fontSize = slotW * 0.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 답 칸
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 3,
          runSpacing: 6,
          children: [
            for (var i = 0; i < n; i++)
              if (_fixed[i] != null)
                SizedBox(
                  width: _fixed[i] == ' ' ? slotW * 0.6 : slotW,
                  height: slotH,
                  child: Center(
                    child: Text(_fixed[i]!, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppTheme.inkSoft)),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _remove(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: slotW,
                    height: slotH,
                    decoration: BoxDecoration(
                      color: _slots[i] == null ? Colors.white : AppTheme.mintSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _slots[i] == null ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.primary, width: 1.6),
                    ),
                    child: Center(
                      child: Text(
                        _slots[i]?.ch ?? '',
                        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppTheme.ink),
                      ),
                    ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 18),
        // 타일 풀
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _pool)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _used.contains(t.id) ? 0.15 : 1,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: _used.contains(t.id) ? 0 : 2,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _used.contains(t.id) ? null : () => _place(t),
                    child: SizedBox(
                      width: 44,
                      height: 50,
                      child: Center(
                        child: Text(t.ch, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
