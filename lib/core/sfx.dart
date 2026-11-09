import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 효과음 (VAVELING 의 장난감 실로폰 소리를 그대로 가져옴).
/// 플러그인이 없는 환경(테스트)이나 웹에서 자동 재생이 막히면 조용히 넘어간다.
enum Sfx { correct, wrong, complete, tap, match, flip, tick, fast, combo1, combo2, combo3, fanfare, hurry, miss }

class SfxService {
  SfxService._();

  static final SfxService instance = SfxService._();

  Future<AudioPlayer>? _player;
  bool enabled = true;

  Future<void> play(Sfx sfx) async {
    if (!enabled) return;
    try {
      final p = await (_player ??= _create());
      await p.stop();
      await p.play(AssetSource('sounds/${sfx.name}.wav'), volume: 0.9);
    } catch (_) {}
  }

  /// 연속 정답 수에 맞춰 콤보 소리를 고른다 (3·5·10).
  Future<void> playForCombo(int combo) {
    if (combo >= 10) return play(Sfx.combo3);
    if (combo >= 5) return play(Sfx.combo2);
    if (combo >= 3) return play(Sfx.combo1);
    return play(Sfx.correct);
  }

  Future<AudioPlayer> _create() async {
    final p = AudioPlayer();
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await p.setAudioContext(AudioContext(android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none)));
      }
      await p.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
    return p;
  }
}
