import 'dart:convert';

import 'package:flutter/services.dart';

import 'term.dart';

/// assets/data/terms.json 을 읽어 든다.
class TermRepo {
  TermRepo._(this.terms, this.categories) : _byId = {for (final t in terms) t.id: t};

  final List<Term> terms;
  final List<TermCategory> categories;
  final Map<String, Term> _byId;

  static Future<TermRepo> load() async {
    final raw = await rootBundle.loadString('assets/data/terms.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final cats = (j['categories'] as List).map((e) => TermCategory.fromJson(e as Map<String, dynamic>)).toList();
    final terms = (j['terms'] as List).map((e) => Term.fromJson(e as Map<String, dynamic>)).toList();
    return TermRepo._(terms, cats);
  }

  Term? byId(String id) => _byId[id];

  TermCategory? category(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// null 이면 전체
  List<Term> inCategory(String? cat) => cat == null ? terms : terms.where((t) => t.cat == cat).toList();

  List<Term> withAbbr(String? cat) => inCategory(cat).where((t) => t.hasAbbr).toList();

  List<Term> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return terms;
    final ko = Term.normKo(s);
    return terms.where((t) {
      if (t.term.toLowerCase().contains(s)) return true;
      if (t.termAlts.any((a) => a.toLowerCase().contains(s))) return true;
      if (t.hasAbbr && t.allAbbrs.any((a) => a.toLowerCase().contains(s))) return true;
      return Term.normKo(t.ko).contains(ko);
    }).toList();
  }
}
