import 'package:flutter/material.dart';

/// 리링 간호사(주인공) 와 VAVELING 친구 8명(병동 안내 캐릭터).
/// 그림: assets/images/mascot/ (tools/make_icon.py), assets/images/characters/ (VAVELING 에서 복사)
class Guide {
  const Guide({required this.id, required this.name, required this.role, required this.color});

  final String id;
  final String name;
  final String role;
  final Color color;

  String get art => 'assets/images/characters/$id.webp';
  String get face => 'assets/images/characters/${id}_face.jpg';

  /// 「리링과」 「모아와」 — 받침에 맞게
  String get withWa => '$name${_hasBatchim(name) ? '과' : '와'}';
  String get subject => '$name${_hasBatchim(name) ? '이' : '가'}';

  static bool _hasBatchim(String s) {
    final c = s.runes.last;
    return c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0;
  }

  static const liling = Guide(id: 'liling', name: '리링', role: '활력징후 담당 간호사', color: Color(0xFF5ECDBE));
  static const doolin = Guide(id: 'doolin', name: '두링', role: '약제실 투약 도우미', color: Color(0xFFF08C6C));
  static const hyeonwoo = Guide(id: 'hyeonwoo', name: '현우 교수', role: '해부학 교수님', color: Color(0xFF8A6A4A));
  static const mei = Guide(id: 'mei', name: '메이', role: '증상 관찰 코치', color: Color(0xFFD9713F));
  static const shanling = Guide(id: 'shanling', name: '산링', role: '병동 수호자', color: Color(0xFF3E8E6A));
  static const lingki = Guide(id: 'lingki', name: '링키', role: '검사실 길잡이', color: Color(0xFF4FA3E0));
  static const moa = Guide(id: 'moa', name: '모아', role: '복습 기록 담당', color: Color(0xFF8C7BE8));
  static const longyue = Guide(id: 'longyue', name: '롱위에', role: '원무과 안내', color: Color(0xFFE88AA8));
  static const longdi = Guide(id: 'longdi', name: '롱디', role: '응급실 파트너', color: Color(0xFF5A8DEE));

  static const all = [liling, doolin, hyeonwoo, mei, shanling, lingki, moa, longyue, longdi];

  static Guide byId(String? id) => all.firstWhere((g) => g.id == id, orElse: () => liling);
}

/// 리링 간호사 그림 경로
class Mascot {
  Mascot._();
  static const body = 'assets/images/mascot/liling_nurse.png';
  static const face = 'assets/images/mascot/liling_nurse_face.png';
}

/// 둥근 얼굴 아바타 (안내 캐릭터)
class GuideAvatar extends StatelessWidget {
  const GuideAvatar(this.guide, {super.key, this.size = 48});

  final Guide guide;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: guide.color, width: 2.5),
        boxShadow: [BoxShadow(color: guide.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ClipOval(child: Image.asset(guide.face, fit: BoxFit.cover)),
    );
  }
}

/// 말풍선
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.color, this.textStyle});

  final String text;
  final Color? color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(text, style: textStyle ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
    );
  }
}

/// 살짝 위아래로 둥실거리는 마스코트
class BobbingMascot extends StatefulWidget {
  const BobbingMascot({super.key, required this.asset, this.height = 180});

  final String asset;
  final double height;

  @override
  State<BobbingMascot> createState() => _BobbingMascotState();
}

class _BobbingMascotState extends State<BobbingMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: child),
      child: Image.asset(widget.asset, height: widget.height, filterQuality: FilterQuality.medium),
    );
  }
}
