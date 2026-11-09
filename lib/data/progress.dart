import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'term.dart';

/// 용어 하나의 학습 상태 (라이트너 상자 방식 간격 반복)
class TermState {
  TermState({this.box = 0, this.due = 0, this.correct = 0, this.wrong = 0, this.fav = false});

  /// 0(처음) ~ 5(완전 암기). 맞히면 +1, 틀리면 -2
  int box;

  /// 다음 복습 시각 (epoch ms)
  int due;
  int correct;
  int wrong;
  bool fav;

  bool get seen => correct + wrong > 0;
  bool get mastered => box >= 4;
  bool get isWeak => seen && (wrong > correct || box == 0);

  Map<String, dynamic> toJson() => {'b': box, 'd': due, 'c': correct, 'w': wrong, if (fav) 'f': 1};

  factory TermState.fromJson(Map<String, dynamic> j) => TermState(
        box: (j['b'] as num?)?.toInt() ?? 0,
        due: (j['d'] as num?)?.toInt() ?? 0,
        correct: (j['c'] as num?)?.toInt() ?? 0,
        wrong: (j['w'] as num?)?.toInt() ?? 0,
        fav: j['f'] == 1,
      );
}

/// 정답 하나를 기록한 결과 (화면이 반응하기 위해)
class AnswerOutcome {
  const AnswerOutcome({required this.xp, required this.leveledUp, required this.goalReached, required this.newBadges});
  final int xp;
  final bool leveledUp;
  final bool goalReached;
  final List<String> newBadges;
}

class StudyBadge {
  const StudyBadge(this.id, this.emoji, this.name, this.desc);
  final String id;
  final String emoji;
  final String name;
  final String desc;

  static const all = <StudyBadge>[
    StudyBadge('first', '🩺', '첫 출근', '첫 문제를 풀었어요'),
    StudyBadge('q50', '📋', '차트 50장', '문제 50개를 풀었어요'),
    StudyBadge('q300', '📚', '차트 300장', '문제 300개를 풀었어요'),
    StudyBadge('combo5', '⚡', '연속 5', '5연속 정답'),
    StudyBadge('combo10', '🔥', '연속 10', '10연속 정답'),
    StudyBadge('streak3', '🌱', '3일 연속', '3일 연속 목표 달성'),
    StudyBadge('streak7', '🌳', '일주일 개근', '7일 연속 목표 달성'),
    StudyBadge('master20', '⭐', '암기 20', '용어 20개 완전 암기'),
    StudyBadge('master100', '🌟', '암기 100', '용어 100개 완전 암기'),
    StudyBadge('perfect', '💯', '퍼펙트', '한 판을 모두 맞혔어요'),
    StudyBadge('hard', '🎓', '하드 모드', '뜻 직접 입력으로 정답'),
    StudyBadge('boss', '👑', '보스 클리어', '완전 정복 한 판 완료'),
  ];

  static StudyBadge? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// 전체 학습 진행도. SharedPreferences 에 JSON 하나로 저장.
class Progress extends ChangeNotifier {
  Progress._();

  static const _key = 'mterm.progress.v1';
  static const intervalsDays = [0, 1, 2, 4, 7, 15];
  static const titles = ['간호학과 새내기', '병동 실습생', '신규 간호사', '프리셉터', '책임 간호사', '수간호사', '전문 간호사', '간호 마스터'];

  int xp = 0;
  int streak = 0;
  String lastGoalDay = '';
  String today = '';
  int todayCount = 0;
  int todayCorrect = 0;
  int dailyGoal = 20;

  bool sound = true;

  /// 뜻을 보기에서 고르지 않고 직접 입력
  bool hardMeaning = false;

  /// 스펠링을 글자 타일로 (끄면 키보드)
  bool tiles = true;
  String? selectedCat;

  int totalAnswered = 0;
  int totalCorrect = 0;
  int bestCombo = 0;
  int sessions = 0;

  final Map<String, TermState> terms = {};

  /// 날짜(yyyy-MM-dd) → 푼 문제 수 (최근 60일만 유지)
  final Map<String, int> history = {};
  final Set<String> badges = {};

  SharedPreferences? _prefs;

  static Future<Progress> load() async {
    final p = Progress._();
    try {
      p._prefs = await SharedPreferences.getInstance();
      final raw = p._prefs!.getString(_key);
      if (raw != null) p._fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    p._rollDay();
    return p;
  }

  // ── 레벨 ──────────────────────────────────────────────────

  static int xpForLevel(int level) => level <= 1 ? 0 : 60 * (level - 1) * (level - 1);

  int get level => (sqrt(max(0, xp) / 60)).floor() + 1;

  double get levelProgress {
    final lo = xpForLevel(level), hi = xpForLevel(level + 1);
    return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  int get xpToNext => xpForLevel(level + 1) - xp;

  String get title => titles[min(level - 1, titles.length - 1)];

  // ── 오늘 ──────────────────────────────────────────────────

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _rollDay() {
    final k = dayKey(DateTime.now());
    if (today == k) return;
    // 어제 목표를 못 채웠으면 연속이 끊긴다 (오늘 채우면 1부터)
    if (lastGoalDay.isNotEmpty && lastGoalDay != k) {
      final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
      if (lastGoalDay != yesterday) streak = 0;
    }
    today = k;
    todayCount = 0;
    todayCorrect = 0;
    // 오래된 기록 정리
    final cutoff = dayKey(DateTime.now().subtract(const Duration(days: 60)));
    history.removeWhere((d, _) => d.compareTo(cutoff) < 0);
  }

  bool get goalReachedToday => todayCount >= dailyGoal;
  double get goalProgress => (todayCount / dailyGoal).clamp(0.0, 1.0);

  // ── 용어 상태 ─────────────────────────────────────────────

  TermState stateOf(String id) => terms.putIfAbsent(id, TermState.new);

  TermState? peek(String id) => terms[id];

  int masteredCount(Iterable<Term> pool) => pool.where((t) => terms[t.id]?.mastered ?? false).length;
  int seenCount(Iterable<Term> pool) => pool.where((t) => terms[t.id]?.seen ?? false).length;

  /// 복습할 때가 된 용어 (본 적 있고, 기한이 지났고, 아직 5상자가 아님)
  List<Term> due(Iterable<Term> pool) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return pool.where((t) {
      final s = terms[t.id];
      return s != null && s.seen && s.box < 5 && s.due <= now;
    }).toList();
  }

  /// 틀린 적이 많은 용어
  List<Term> weak(Iterable<Term> pool) => pool.where((t) => terms[t.id]?.isWeak ?? false).toList();

  List<Term> favorites(Iterable<Term> pool) => pool.where((t) => terms[t.id]?.fav ?? false).toList();

  void toggleFav(String id) {
    final s = stateOf(id);
    s.fav = !s.fav;
    save();
    notifyListeners();
  }

  /// 정답/오답 하나 기록. 경험치·연속·배지까지 처리한다.
  AnswerOutcome record(String id, bool correct, {int combo = 1, bool hard = false, int baseXp = 10}) {
    _rollDay();
    final s = stateOf(id);
    final now = DateTime.now();
    final beforeLevel = level;
    final beforeGoal = goalReachedToday;
    int gained = 0;
    if (correct) {
      s.correct++;
      s.box = min<int>(5, s.box + 1);
      gained = baseXp + min<int>(10, max<int>(0, combo - 1) * 2) + (hard ? 5 : 0);
      totalCorrect++;
      todayCorrect++;
    } else {
      s.wrong++;
      s.box = max<int>(0, s.box - 2);
      gained = 1;
    }
    s.due = now.add(Duration(days: intervalsDays[s.box])).millisecondsSinceEpoch;
    if (!correct) s.due = now.millisecondsSinceEpoch; // 틀린 건 바로 다시
    xp += gained;
    totalAnswered++;
    todayCount++;
    history[today] = ((history[today] ?? 0) + 1).toInt();
    bestCombo = max(bestCombo, combo);

    bool goalNow = false;
    if (!beforeGoal && goalReachedToday) {
      goalNow = true;
      if (lastGoalDay != today) {
        final yesterday = dayKey(now.subtract(const Duration(days: 1)));
        streak = lastGoalDay == yesterday ? streak + 1 : 1;
        lastGoalDay = today;
      }
    }
    final newBadges = <String>[];
    void earn(String b) {
      if (badges.add(b)) newBadges.add(b);
    }

    earn('first');
    if (totalAnswered >= 50) earn('q50');
    if (totalAnswered >= 300) earn('q300');
    if (combo >= 5 && correct) earn('combo5');
    if (combo >= 10 && correct) earn('combo10');
    if (streak >= 3) earn('streak3');
    if (streak >= 7) earn('streak7');
    if (hard && correct) earn('hard');
    final mastered = terms.values.where((t) => t.mastered).length;
    if (mastered >= 20) earn('master20');
    if (mastered >= 100) earn('master100');

    save();
    notifyListeners();
    return AnswerOutcome(xp: gained, leveledUp: level > beforeLevel, goalReached: goalNow, newBadges: newBadges);
  }

  /// 한 판 끝: 퍼펙트·보스 배지, 판 수
  List<String> finishSession({required bool perfect, required bool boss, int bonusXp = 0}) {
    sessions++;
    final newBadges = <String>[];
    if (perfect && badges.add('perfect')) newBadges.add('perfect');
    if (boss && badges.add('boss')) newBadges.add('boss');
    xp += bonusXp;
    save();
    notifyListeners();
    return newBadges;
  }

  void setSound(bool v) {
    sound = v;
    save();
    notifyListeners();
  }

  void setHardMeaning(bool v) {
    hardMeaning = v;
    save();
    notifyListeners();
  }

  void setTiles(bool v) {
    tiles = v;
    save();
    notifyListeners();
  }

  void setDailyGoal(int v) {
    dailyGoal = v;
    save();
    notifyListeners();
  }

  void setCategory(String? cat) {
    selectedCat = cat;
    save();
    notifyListeners();
  }

  Future<void> reset() async {
    xp = 0;
    streak = 0;
    lastGoalDay = '';
    todayCount = 0;
    todayCorrect = 0;
    totalAnswered = 0;
    totalCorrect = 0;
    bestCombo = 0;
    sessions = 0;
    terms.clear();
    history.clear();
    badges.clear();
    await save();
    notifyListeners();
  }

  // ── 저장 ──────────────────────────────────────────────────

  Map<String, dynamic> _toJson() => {
        'xp': xp,
        'streak': streak,
        'lastGoalDay': lastGoalDay,
        'today': today,
        'todayCount': todayCount,
        'todayCorrect': todayCorrect,
        'dailyGoal': dailyGoal,
        'sound': sound,
        'hardMeaning': hardMeaning,
        'tiles': tiles,
        'selectedCat': selectedCat,
        'totalAnswered': totalAnswered,
        'totalCorrect': totalCorrect,
        'bestCombo': bestCombo,
        'sessions': sessions,
        'terms': {for (final e in terms.entries) e.key: e.value.toJson()},
        'history': history,
        'badges': badges.toList(),
      };

  void _fromJson(Map<String, dynamic> j) {
    xp = (j['xp'] as num?)?.toInt() ?? 0;
    streak = (j['streak'] as num?)?.toInt() ?? 0;
    lastGoalDay = j['lastGoalDay'] as String? ?? '';
    today = j['today'] as String? ?? '';
    todayCount = (j['todayCount'] as num?)?.toInt() ?? 0;
    todayCorrect = (j['todayCorrect'] as num?)?.toInt() ?? 0;
    dailyGoal = (j['dailyGoal'] as num?)?.toInt() ?? 20;
    sound = j['sound'] as bool? ?? true;
    hardMeaning = j['hardMeaning'] as bool? ?? false;
    tiles = j['tiles'] as bool? ?? true;
    selectedCat = j['selectedCat'] as String?;
    totalAnswered = (j['totalAnswered'] as num?)?.toInt() ?? 0;
    totalCorrect = (j['totalCorrect'] as num?)?.toInt() ?? 0;
    bestCombo = (j['bestCombo'] as num?)?.toInt() ?? 0;
    sessions = (j['sessions'] as num?)?.toInt() ?? 0;
    (j['terms'] as Map<String, dynamic>? ?? {}).forEach((k, v) => terms[k] = TermState.fromJson(v as Map<String, dynamic>));
    (j['history'] as Map<String, dynamic>? ?? {}).forEach((k, v) => history[k] = (v as num).toInt());
    badges.addAll((j['badges'] as List? ?? const []).cast<String>());
  }

  Future<void> save() async {
    try {
      await _prefs?.setString(_key, jsonEncode(_toJson()));
    } catch (_) {}
  }
}
