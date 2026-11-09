import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/characters.dart';
import '../core/sfx.dart';
import '../data/term.dart';
import 'letter_tiles.dart';
import 'quiz_engine.dart';
import 'result_screen.dart';

/// 한 판 진행 화면. 문제 유형마다 입력 위젯이 다르고, 답하면 아래에서 피드백 패널이 올라온다.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.session});

  final QuizSession session;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

enum _Phase { answering, feedback }

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  QuizSession get s => widget.session;

  _Phase _phase = _Phase.answering;
  bool? _lastCorrect;
  String _lastInput = '';
  int _lastXp = 0;

  // 약어 풀기 2단계
  int _step = 0;
  String _step1Input = '';
  bool _step1Ok = false;

  // 글자 타일
  GlobalKey<LetterTilesState> _tilesKey = GlobalKey();
  bool _useKeyboard = false;
  final _text = TextEditingController();
  final _focus = FocusNode();

  int? _chosen;

  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _shake.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _prepare() {
    final p = AppScope.of(context).progress;
    final q = s.current;
    _step = 0;
    _step1Input = '';
    _step1Ok = false;
    _chosen = null;
    _text.clear();
    _tilesKey = GlobalKey();
    // 긴 용어는 타일이 너무 많아 키보드로
    _useKeyboard = !p.tiles || q.term.letterCount > 16;
    if (q.type == QType.abbrType) _useKeyboard = true;
  }

  // ── 채점 ──────────────────────────────────────────────────

  void _submitChoice(int i) {
    if (_phase != _Phase.answering) return;
    final q = s.current;
    setState(() => _chosen = i);
    if (q.type == QType.abbrExpand) {
      // 2단계(뜻 고르기)
      _finish(correct: _step1Ok && i == q.answer, input: '$_step1Input · ${q.choices[i]}');
      return;
    }
    _finish(correct: i == q.answer, input: q.choices[i]);
  }

  void _submitText(String input) {
    if (_phase != _Phase.answering) return;
    final q = s.current;
    final t = q.term;
    final v = input.trim();
    if (v.isEmpty) return;
    final p = AppScope.of(context).progress;
    switch (q.type) {
      case QType.spellTerm:
        _finish(correct: t.matchesTerm(v), input: v);
      case QType.abbrType:
        _finish(correct: t.matchesAbbr(v), input: v);
      case QType.abbrExpand:
        if (_step == 0) {
          // 1단계 철자 → 2단계로. 틀렸어도 2단계까지 가서 한꺼번에 알려 준다.
          _step1Input = v;
          _step1Ok = t.matchesTerm(v);
          SfxService.instance.play(_step1Ok ? Sfx.match : Sfx.tick);
          setState(() {
            _step = 1;
            _text.clear();
            _useKeyboard = true; // 뜻 입력(하드) 은 키보드
          });
          if (p.hardMeaning) Future.delayed(const Duration(milliseconds: 100), () => _focus.requestFocus());
        } else {
          // 2단계 뜻 직접 입력 (하드 모드)
          _finish(correct: _step1Ok && t.matchesKo(v), input: '$_step1Input · $v', hard: true);
        }
      default:
        break;
    }
  }

  void _finish({required bool correct, required String input, bool hard = false}) {
    final p = AppScope.of(context).progress;
    final q = s.current;
    if (correct) {
      s.combo++;
      if (s.combo > s.maxCombo) s.maxCombo = s.combo;
      SfxService.instance.playForCombo(s.combo);
    } else {
      s.combo = 0;
      if (s.hearts > 0) s.hearts--;
      SfxService.instance.play(Sfx.wrong);
      _shake.forward(from: 0);
    }
    final base = switch (q.type) {
      QType.meaningChoice || QType.termChoice => 8,
      QType.spellTerm => 12,
      QType.abbrType => 12,
      QType.abbrExpand => 16,
    };
    final outcome = p.record(q.term.id, correct, combo: s.combo, hard: hard || p.hardMeaning && q.type == QType.abbrExpand, baseXp: base);
    s.xpEarned += outcome.xp;
    if (outcome.leveledUp) s.leveledUp = true;
    s.newBadges.addAll(outcome.newBadges);
    s.results.add(QuestionResult(term: q.term, correct: correct, userAnswer: input));
    if (!correct && s.mode.requeueWrong) {
      s.questions.add(QuizEngine(AppScope.of(context).repo, p).retryOf(q));
      s.retries++;
    }
    setState(() {
      _phase = _Phase.feedback;
      _lastCorrect = correct;
      _lastInput = input;
      _lastXp = outcome.xp;
    });
    if (outcome.goalReached && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 오늘 목표 달성! 연속 기록이 이어져요'), behavior: SnackBarBehavior.floating));
    }
  }

  void _next() {
    s.index++;
    if (s.finished) {
      final p = AppScope.of(context).progress;
      final bonus = s.perfect ? 30 : (s.mode.isBoss && s.hearts > 0 ? 20 : 0);
      s.xpEarned += bonus;
      s.newBadges.addAll(p.finishSession(perfect: s.perfect, boss: s.mode.isBoss && s.hearts > 0, bonusXp: bonus));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(session: s)));
      return;
    }
    setState(() {
      _phase = _Phase.answering;
      _lastCorrect = null;
      _prepare();
    });
  }

  Future<bool> _confirmExit() async {
    if (s.results.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('그만둘까요?'),
        content: Text('지금까지 ${s.results.length}문제 푼 기록은 저장돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('계속 풀기')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('그만두기')),
        ],
      ),
    );
    return ok ?? false;
  }

  // ── 화면 ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final q = s.current;
    final cat = scope.repo.category(q.term.cat);
    final guide = Guide.byId(cat?.guide);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(session: s, onClose: () async {
                if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
              }),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GuideAvatar(guide, size: 46),
                          const SizedBox(width: 10),
                          Expanded(child: SpeechBubble(text: _prompt(q, guide))),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) {
                          final t = _shake.value;
                          final dx = t == 0 || t == 1 ? 0.0 : 8 * (1 - t) * ((t * 20).floor().isEven ? 1 : -1);
                          return Transform.translate(offset: Offset(dx, 0), child: child);
                        },
                        child: _QuestionCard(question: q, step: _step, step1Input: _step1Input),
                      ),
                      const SizedBox(height: 18),
                      _buildInput(q),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _phase == _Phase.feedback
                    ? _Feedback(
                        correct: _lastCorrect!,
                        term: q.term,
                        input: _lastInput,
                        xp: _lastXp,
                        combo: s.combo,
                        isLast: s.index + 1 >= s.questions.length || s.hearts == 0,
                        requeued: !_lastCorrect! && s.mode.requeueWrong,
                        onNext: _next,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _prompt(Question q, Guide g) {
    switch (q.type) {
      case QType.meaningChoice:
        return '이 용어의 뜻은 무엇일까요?';
      case QType.termChoice:
        return '이 뜻에 맞는 영어 용어를 골라요!';
      case QType.spellTerm:
        return _useKeyboard ? '영어 철자를 직접 입력해 봐요!' : '글자 타일을 눌러 철자를 완성해요!';
      case QType.abbrType:
        return '이 용어의 약어를 써 봐요! (대소문자 상관없어요)';
      case QType.abbrExpand:
        if (_step == 0) return '약어의 풀네임(철자)을 완성해요! 1/2';
        final p = AppScope.of(context).progress;
        return p.hardMeaning ? '이제 뜻을 한국어로 적어요! 2/2' : '이제 뜻을 골라요! 2/2';
    }
  }

  Widget _buildInput(Question q) {
    final answering = _phase == _Phase.answering;
    switch (q.type) {
      case QType.meaningChoice:
      case QType.termChoice:
        return _Choices(question: q, chosen: _chosen, enabled: answering, onPick: _submitChoice);
      case QType.abbrExpand:
        if (_step == 1) {
          final p = AppScope.of(context).progress;
          if (p.hardMeaning) return _typingInput(q, hintKo: true);
          return _Choices(question: q, chosen: _chosen, enabled: answering, onPick: _submitChoice);
        }
        return _spellInput(q);
      case QType.spellTerm:
        return _spellInput(q);
      case QType.abbrType:
        return _typingInput(q);
    }
  }

  Widget _spellInput(Question q) {
    if (_useKeyboard) return _typingInput(q);
    final answering = _phase == _Phase.answering;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LetterTiles(
          key: _tilesKey,
          answer: q.term.term,
          enabled: answering,
          distractors: q.term.letterCount > 10 ? 3 : 2,
          onComplete: _submitText,
        ),
        const SizedBox(height: 12),
        if (answering)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _tilesKey.currentState?.hint(),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('힌트 한 글자'),
              ),
              TextButton.icon(
                onPressed: () => _tilesKey.currentState?.clear(),
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('지우기'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _useKeyboard = true),
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('키보드'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _typingInput(Question q, {bool hintKo = false}) {
    final answering = _phase == _Phase.answering;
    final isAbbr = q.type == QType.abbrType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          focusNode: _focus,
          enabled: answering,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: hintKo ? TextInputType.text : TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          decoration: InputDecoration(
            hintText: hintKo
                ? '뜻을 한국어로 입력'
                : isAbbr
                    ? '약어 입력 (예: BP)'
                    : '영어 철자 입력',
            suffixIcon: IconButton(icon: const Icon(Icons.send_rounded, color: AppTheme.primary), onPressed: () => _submitText(_text.text)),
          ),
          onSubmitted: _submitText,
        ),
        const SizedBox(height: 8),
        if (answering && !hintKo && !isAbbr)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () {
                  // 첫 글자 힌트
                  final a = q.term.term;
                  final cur = _text.text;
                  final next = a.length > cur.length ? a.substring(0, cur.length + 1) : a;
                  _text.text = next;
                  _text.selection = TextSelection.collapsed(offset: next.length);
                },
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('힌트 한 글자'),
              ),
              if (q.term.letterCount <= 16)
                TextButton.icon(
                  onPressed: () => setState(() => _useKeyboard = false),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('타일로'),
                ),
            ],
          ),
      ],
    );
  }
}

// ── 조각 위젯 ───────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.onClose});
  final QuizSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (s.index + (s.results.length > s.index ? 1 : 0)) / s.questions.length,
                minHeight: 10,
                backgroundColor: AppTheme.mintSoft,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${s.index + 1}/${s.questions.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
          if (s.current.retry) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.star.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
              child: const Text('재도전', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(width: 10),
          if (s.combo >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(10)),
              child: Text('🔥 ${s.combo}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
            ),
          if (s.hearts >= 0) ...[
            const SizedBox(width: 6),
            for (var i = 0; i < 3; i++)
              Icon(i < s.hearts ? Icons.favorite : Icons.favorite_border, color: AppTheme.pink, size: 20),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.step, required this.step1Input});
  final Question question;
  final int step;
  final String step1Input;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final t = q.term;
    final cat = AppScope.of(context).repo.category(t.cat);
    Widget big(String s, {double size = 30}) => Text(s, textAlign: TextAlign.center, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.2));
    Widget sub(String s) => Text(s, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppTheme.inkSoft, fontWeight: FontWeight.w600));

    final children = <Widget>[];
    switch (q.type) {
      case QType.meaningChoice:
        children.add(big(t.term));
        if (t.hasAbbr) children.add(Padding(padding: const EdgeInsets.only(top: 6), child: _AbbrChip(t.abbr)));
      case QType.termChoice:
        children.add(big(t.ko, size: 26));
      case QType.spellTerm:
        children.add(big(t.ko, size: 26));
        children.add(Padding(padding: const EdgeInsets.only(top: 6), child: sub('철자 ${t.letterCount}자')));
      case QType.abbrType:
        children.add(big(t.term, size: 26));
        children.add(Padding(padding: const EdgeInsets.only(top: 6), child: sub(t.ko)));
      case QType.abbrExpand:
        children.add(_AbbrChip(t.abbr, large: true));
        if (step == 1) {
          children.add(const SizedBox(height: 10));
          children.add(Text(step1Input, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primary)));
        } else {
          children.add(Padding(padding: const EdgeInsets.only(top: 8), child: sub('풀네임 철자 ${t.letterCount}자')));
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (cat?.color ?? AppTheme.primary).withValues(alpha: 0.35), width: 1.5),
        boxShadow: [BoxShadow(color: (cat?.color ?? AppTheme.primary).withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          if (cat != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${cat.emoji} ${cat.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cat.color)),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _AbbrChip extends StatelessWidget {
  const _AbbrChip(this.abbr, {this.large = false});
  final String abbr;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 22 : 12, vertical: large ? 10 : 4),
      decoration: BoxDecoration(color: AppTheme.pinkSoft, borderRadius: BorderRadius.circular(large ? 16 : 10)),
      child: Text(abbr, style: TextStyle(fontSize: large ? 36 : 16, fontWeight: FontWeight.w900, color: AppTheme.ink, letterSpacing: 1)),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.question, required this.chosen, required this.enabled, required this.onPick});
  final Question question;
  final int? chosen;
  final bool enabled;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Column(
      children: [
        for (var i = 0; i < q.choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceButton(
              text: q.choices[i],
              state: !enabled && chosen != null
                  ? (i == q.answer ? _ChoiceState.right : (i == chosen ? _ChoiceState.wrong : _ChoiceState.idle))
                  : _ChoiceState.idle,
              onTap: enabled ? () => onPick(i) : null,
            ),
          ),
      ],
    );
  }
}

enum _ChoiceState { idle, right, wrong }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.text, required this.state, required this.onTap});
  final String text;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _ChoiceState.idle => Colors.white,
      _ChoiceState.right => AppTheme.correct.withValues(alpha: 0.15),
      _ChoiceState.wrong => AppTheme.wrong.withValues(alpha: 0.15),
    };
    final border = switch (state) {
      _ChoiceState.idle => AppTheme.primary.withValues(alpha: 0.3),
      _ChoiceState.right => AppTheme.correct,
      _ChoiceState.wrong => AppTheme.wrong,
    };
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTheme.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 1.6)),
          child: Row(
            children: [
              Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              if (state == _ChoiceState.right) const Icon(Icons.check_circle, color: AppTheme.correct),
              if (state == _ChoiceState.wrong) const Icon(Icons.cancel, color: AppTheme.wrong),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.correct,
    required this.term,
    required this.input,
    required this.xp,
    required this.combo,
    required this.isLast,
    required this.onNext,
    this.requeued = false,
  });

  final bool correct;
  final Term term;
  final String input;
  final int xp;
  final int combo;
  final bool isLast;
  final VoidCallback onNext;
  final bool requeued;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppTheme.correct : AppTheme.wrong;
    final msgs = correct
        ? const ['정답! 역시 믿고 있었어요 💕', '완벽해요! 차트에 ⭐ 하나', '좋아요! 환자분도 안심하겠어요', '정확해요! 멋진 간호사 👩‍⚕️']
        : const ['괜찮아요, 이 용어는 곧 다시 나와요', '아쉬워요! 정답을 한 번 더 눈에 담아요', '틀려도 괜찮아요, 외우는 중이니까요'];
    final msg = msgs[(term.id.hashCode.abs()) % msgs.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5), color: Colors.white),
                  child: ClipOval(child: Image.asset(Mascot.face, fit: BoxFit.cover)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(correct ? (combo >= 3 ? '🔥 $combo 연속 정답!' : '정답!') : '아쉬워요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                      Text(msg, style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text('+$xp XP', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (term.hasAbbr) ...[_AbbrChip(term.abbr), const SizedBox(width: 8)],
                      Expanded(child: Text(term.termDisplay, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(term.ko, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.inkSoft)),
                  if (!correct && input.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('내 답: $input', style: const TextStyle(fontSize: 13, color: AppTheme.wrong, fontWeight: FontWeight.w600)),
                  ],
                  if (requeued) ...[
                    const SizedBox(height: 6),
                    const Text('🎯 이 문제는 뒤에 다시 나와요. 맞힐 때까지!', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(isLast ? '결과 보기' : '다음'),
            ),
          ],
        ),
      ),
    );
  }
}
