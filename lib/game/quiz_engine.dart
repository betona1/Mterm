import 'dart:math';

import '../data/progress.dart';
import '../data/term.dart';
import '../data/term_repo.dart';

/// 게임 모드
enum QuizMode {
  meaning('뜻 맞추기', '용어 ↔ 뜻을 보기에서 고르기', '🧩'),
  spelling('스펠링', '뜻을 보고 영어 철자를 완성', '✏️'),
  abbr('약어 정복', '약어 → 풀네임 철자 + 뜻까지', '🔤'),
  boss('완전 정복', '철자·약어·뜻 모두! 하트 3개', '👑'),
  mastery('만점 도전', '틀리면 다시 나와요. 전부 맞힐 때까지!', '🎯'),
  review('복습', '잊기 전에 다시 꺼내는 용어', '🔁'),
  wrong('틀린 문제', '자주 틀린 용어만 모아서', '🩹'),
  flash('플래시카드', '카드 넘기며 눈에 익히기', '🃏');

  const QuizMode(this.label, this.desc, this.emoji);
  final String label;
  final String desc;
  final String emoji;

  bool get isBoss => this == QuizMode.boss;

  /// 틀린 문제를 뒤에 다시 붙여 전부 맞힐 때까지 계속
  bool get requeueWrong => this == QuizMode.mastery;
}

/// 문제 유형
enum QType {
  /// 용어(+약어) 보고 뜻 고르기
  meaningChoice,

  /// 뜻 보고 용어 고르기
  termChoice,

  /// 뜻 보고 철자 쓰기
  spellTerm,

  /// 약어 → 풀네임 철자 + 뜻
  abbrExpand,

  /// 용어 + 뜻 → 약어 쓰기
  abbrType,
}

class Question {
  Question({required this.term, required this.type, this.choices = const [], this.answer = -1, this.retry = false});

  final Term term;
  final QType type;

  /// 보기 (뜻 또는 용어 문자열). abbrExpand 는 2단계 뜻 보기.
  final List<String> choices;
  final int answer;

  /// 틀려서 다시 나온 문제
  final bool retry;

  bool get needsTyping => type == QType.spellTerm || type == QType.abbrExpand || type == QType.abbrType;
}

class QuestionResult {
  QuestionResult({required this.term, required this.correct, required this.userAnswer});
  final Term term;
  final bool correct;
  final String userAnswer;
}

class QuizSession {
  QuizSession({required this.mode, required this.questions, required this.categoryId, this.hearts = -1});

  final QuizMode mode;
  final List<Question> questions;
  final String? categoryId;

  /// -1 이면 무제한
  int hearts;
  int index = 0;
  int combo = 0;
  int maxCombo = 0;
  int xpEarned = 0;
  bool leveledUp = false;

  /// 만점 도전에서 다시 붙인 문제 수
  int retries = 0;
  final List<QuestionResult> results = [];
  final List<String> newBadges = [];

  Question get current => questions[index];
  bool get finished => index >= questions.length || hearts == 0;
  int get correctCount => results.where((r) => r.correct).length;

  /// 처음 낸 문제 수 (다시 붙인 것 제외)
  int get baseCount => questions.where((q) => !q.retry).length;
  bool get perfect => results.isNotEmpty && results.every((r) => r.correct) && results.length == questions.length;

  /// 틀린 적 있는 용어 (중복 없이)
  List<Term> get wrongTerms {
    final seen = <String>{};
    return [for (final r in results) if (!r.correct && seen.add(r.term.id)) r.term];
  }
}

class QuizEngine {
  QuizEngine(this.repo, this.progress, {Random? rnd}) : _rnd = rnd ?? Random();

  final TermRepo repo;
  final Progress progress;
  final Random _rnd;

  static const defaultCount = 10;
  static const bossCount = 15;

  /// 모드·분류에 맞는 한 판을 만든다. 풀이 모자라면 있는 만큼.
  QuizSession? build(QuizMode mode, {String? cat, List<Term>? customPool, int? count}) {
    List<Term> pool;
    switch (mode) {
      case QuizMode.abbr:
        pool = customPool ?? repo.withAbbr(cat);
      case QuizMode.review:
        pool = customPool ?? progress.due(repo.inCategory(cat));
      case QuizMode.wrong:
        pool = customPool ?? progress.weak(repo.inCategory(cat));
      default:
        pool = customPool ?? repo.inCategory(cat);
    }
    if (pool.isEmpty) return null;
    final n = count ?? (mode.isBoss ? bossCount : defaultCount);
    final picked = _pick(pool, n);
    final questions = <Question>[];
    for (var i = 0; i < picked.length; i++) {
      questions.add(_make(picked[i], mode, i));
    }
    return QuizSession(mode: mode, questions: questions, categoryId: cat, hearts: mode.isBoss ? 3 : -1);
  }

  /// 틀린 문제를 같은 유형으로 다시 만든다 (보기는 새로 섞는다)
  Question retryOf(Question q) {
    switch (q.type) {
      case QType.meaningChoice:
        return _meaningChoice(q.term, retry: true);
      case QType.termChoice:
        return _termChoice(q.term, retry: true);
      case QType.abbrExpand:
        return _abbrExpand(q.term, retry: true);
      case QType.spellTerm:
      case QType.abbrType:
        return Question(term: q.term, type: q.type, retry: true);
    }
  }

  /// 아직 덜 외운 것부터, 섞어서 n 개
  List<Term> _pick(List<Term> pool, int n) {
    final list = [...pool]..shuffle(_rnd);
    list.sort((a, b) => (progress.peek(a.id)?.box ?? 0).compareTo(progress.peek(b.id)?.box ?? 0));
    final head = list.take(min(list.length, n * 2)).toList()..shuffle(_rnd);
    return head.take(n).toList();
  }

  Question _make(Term t, QuizMode mode, int i) {
    switch (mode) {
      case QuizMode.meaning:
        return i.isEven ? _meaningChoice(t) : _termChoice(t);
      case QuizMode.spelling:
        return Question(term: t, type: QType.spellTerm);
      case QuizMode.abbr:
        return i % 3 == 2 ? Question(term: t, type: QType.abbrType) : _abbrExpand(t);
      case QuizMode.boss:
      case QuizMode.mastery:
        if (t.hasAbbr) return i % 4 == 3 ? Question(term: t, type: QType.abbrType) : _abbrExpand(t);
        return i % 3 == 0 ? _termChoice(t) : Question(term: t, type: QType.spellTerm);
      case QuizMode.review:
      case QuizMode.wrong:
        final box = progress.peek(t.id)?.box ?? 0;
        if (box <= 1) return i.isEven ? _meaningChoice(t) : _termChoice(t);
        if (box <= 3 || !t.hasAbbr) return Question(term: t, type: QType.spellTerm);
        return _abbrExpand(t);
      case QuizMode.flash:
        return _meaningChoice(t);
    }
  }

  Question _meaningChoice(Term t, {bool retry = false}) {
    final c = _distractors(t, (x) => x.koMain, t.koMain);
    return Question(term: t, type: QType.meaningChoice, choices: c.$1, answer: c.$2, retry: retry);
  }

  Question _termChoice(Term t, {bool retry = false}) {
    final c = _distractors(t, (x) => x.term, t.term);
    return Question(term: t, type: QType.termChoice, choices: c.$1, answer: c.$2, retry: retry);
  }

  Question _abbrExpand(Term t, {bool retry = false}) {
    final c = _distractors(t, (x) => x.koMain, t.koMain);
    return Question(term: t, type: QType.abbrExpand, choices: c.$1, answer: c.$2, retry: retry);
  }

  /// 같은 분류에서 3개, 모자라면 전체에서. (보기, 정답 위치)
  (List<String>, int) _distractors(Term t, String Function(Term) f, String answer) {
    final seen = <String>{Term.normKo(answer).toLowerCase()};
    final out = <String>[];
    void take(List<Term> from) {
      final c = [...from]..shuffle(_rnd);
      for (final x in c) {
        if (out.length >= 3) break;
        if (x.id == t.id) continue;
        final v = f(x);
        final k = Term.normKo(v).toLowerCase();
        if (seen.add(k)) out.add(v);
      }
    }

    take(repo.inCategory(t.cat));
    if (out.length < 3) take(repo.terms);
    final idx = _rnd.nextInt(out.length + 1);
    out.insert(idx, answer);
    return (out, idx);
  }
}
