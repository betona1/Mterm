import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mterm/data/term.dart';

void main() {
  const bp = Term(id: 'blood_pressure', term: 'blood pressure', termAlts: [], abbr: 'BP', abbrAlts: [], ko: '혈압', cat: 'vital');
  const hb = Term(id: 'hemoglobin', term: 'hemoglobin', termAlts: [], abbr: 'Hb', abbrAlts: ['Hgb'], ko: '혈색소, 헤모글로빈', cat: 'test');
  const fowler = Term(id: 'semi_fowler', term: "semi-Fowler position", termAlts: ["semi-Fowler's position"], abbr: '', abbrAlts: [], ko: '반좌위', cat: 'care');

  test('철자 판정은 대소문자·공백·기호를 무시한다', () {
    expect(bp.matchesTerm('Blood Pressure'), isTrue);
    expect(bp.matchesTerm('bloodpressure'), isTrue);
    expect(bp.matchesTerm('blood presure'), isFalse);
    expect(fowler.matchesTerm('semi fowler position'), isTrue);
    expect(fowler.matchesTerm("Semi-Fowler's Position"), isTrue);
  });

  test('약어는 대체 표기도 인정한다', () {
    expect(hb.matchesAbbr('hb'), isTrue);
    expect(hb.matchesAbbr('HGB'), isTrue);
    expect(hb.matchesAbbr('hct'), isFalse);
    expect(fowler.hasAbbr, isFalse);
  });

  test('뜻은 쉼표로 나뉜 후보 중 하나면 정답', () {
    expect(hb.matchesKo('헤모글로빈'), isTrue);
    expect(hb.matchesKo('혈색소'), isTrue);
    expect(hb.matchesKo('혈 색소'), isTrue);
    expect(hb.matchesKo('혈소판'), isFalse);
    expect(bp.matchesKo('혈'), isFalse); // 한 글자는 안 됨
  });

  test('terms.json 이 읽히고 id 가 겹치지 않는다', () {
    final raw = File('assets/data/terms.json').readAsStringSync();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final terms = (j['terms'] as List).map((e) => Term.fromJson(e as Map<String, dynamic>)).toList();
    expect(terms.length, greaterThan(300));
    expect(terms.map((t) => t.id).toSet().length, terms.length);
    final cats = (j['categories'] as List).map((e) => (e as Map)['id'] as String).toSet();
    for (final t in terms) {
      expect(cats.contains(t.cat), isTrue, reason: '${t.term} 의 분류 ${t.cat}');
      expect(t.koAlts, isNotEmpty);
    }
    // 같은 약어가 두 용어에 쓰이면 약어 → 용어 문제가 애매해진다
    final abbrOwners = <String, List<String>>{};
    for (final t in terms) {
      for (final a in t.allAbbrs) {
        abbrOwners.putIfAbsent(a.toLowerCase(), () => []).add(t.term);
      }
    }
    final dup = abbrOwners.entries.where((e) => e.value.length > 1).toList();
    expect(dup, isEmpty, reason: '중복 약어: ${dup.map((e) => '${e.key}=${e.value}').join(', ')}');
    expect(max(1, terms.where((t) => t.hasAbbr).length), greaterThan(150));
  });
}
