import 'package:flutter/material.dart';

/// 용어 하나: 약어(선택) · 영어 용어 · 한국어 뜻 · 분류
class Term {
  const Term({
    required this.id,
    required this.term,
    required this.termAlts,
    required this.abbr,
    required this.abbrAlts,
    required this.ko,
    required this.cat,
  });

  final String id;
  final String term;
  final List<String> termAlts;
  final String abbr;
  final List<String> abbrAlts;
  final String ko;
  final String cat;

  bool get hasAbbr => abbr.isNotEmpty;

  List<String> get allTerms => [term, ...termAlts];
  List<String> get allAbbrs => hasAbbr ? [abbr, ...abbrAlts] : const [];

  /// 「혈색소, 헤모글로빈」 → [혈색소, 헤모글로빈]. 각각이 정답으로 인정된다.
  List<String> get koAlts =>
      ko.split(RegExp(r'[,/]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList(growable: false);

  String get koMain => koAlts.first;

  /// 화면 표기용 영어 (대체 표기 괄호)
  String get termDisplay => termAlts.isEmpty ? term : '$term (${termAlts.join(', ')})';

  /// 알파벳만 센 길이 (타일 입력 여부 판단)
  int get letterCount => term.replaceAll(RegExp(r'[^A-Za-z]'), '').length;

  factory Term.fromJson(Map<String, dynamic> j) => Term(
        id: j['id'] as String,
        term: j['term'] as String,
        termAlts: (j['termAlts'] as List? ?? const []).cast<String>(),
        abbr: (j['abbr'] as String?) ?? '',
        abbrAlts: (j['abbrAlts'] as List? ?? const []).cast<String>(),
        ko: j['ko'] as String,
        cat: j['cat'] as String,
      );

  // ── 정답 판정 ──────────────────────────────────────────────

  /// 영어 비교용: 소문자, 알파벳·숫자만
  static String normEn(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// 한국어 비교용: 공백·문장부호 제거
  static String normKo(String s) => s.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');

  bool matchesTerm(String input) {
    final n = normEn(input);
    return n.isNotEmpty && allTerms.any((t) => normEn(t) == n);
  }

  bool matchesAbbr(String input) {
    final n = normEn(input);
    return n.isNotEmpty && allAbbrs.any((a) => normEn(a) == n);
  }

  /// 뜻 직접 입력: 후보 중 하나와 같거나, 두 글자 이상이면서 서로 포함하면 인정
  bool matchesKo(String input) {
    final n = normKo(input);
    if (n.isEmpty) return false;
    for (final alt in koAlts) {
      final a = normKo(alt.replaceAll(RegExp(r'\(.*?\)'), ''));
      if (a == n) return true;
      if (n.length >= 2 && (a.contains(n) || n.contains(a))) return true;
    }
    return false;
  }
}

class TermCategory {
  const TermCategory({required this.id, required this.name, required this.emoji, required this.guide, required this.color});

  final String id;
  final String name;
  final String emoji;
  final String guide;
  final Color color;

  factory TermCategory.fromJson(Map<String, dynamic> j) => TermCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        guide: j['guide'] as String,
        color: _hex(j['color'] as String),
      );

  static Color _hex(String s) => Color(int.parse(s.replaceFirst('#', 'FF'), radix: 16));
}
