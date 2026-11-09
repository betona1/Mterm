import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'characters.dart';

/// 깃허브 릴리스로 자동 업데이트 (안드로이드만).
/// GitHub Actions(.github/workflows/release.yml) 가 main 에 푸시될 때마다 APK 를 빌드해
/// `v<버전>+<빌드번호>` 태그의 릴리스에 올린다. 앱은 켜질 때 최신 릴리스를 보고 더 새 것이면 안내한다.
/// 설치는 브라우저가 내려받은 APK 를 눌러서 — 같은 서명 키라 덮어 설치가 된다.
enum UpdateResult { unsupported, upToDate, shown, failed }

class UpdateCheck {
  UpdateCheck._();

  static const repo = 'betona1/Mterm';
  static const _api = 'https://api.github.com/repos/$repo/releases/latest';

  /// 홈이 뜬 뒤 한 번, 그리고 설정의 「업데이트 확인」 버튼에서 부른다. 실패하면 조용히 넘어간다.
  static Future<UpdateResult> run(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return UpdateResult.unsupported;
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http.get(Uri.parse(_api), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return UpdateResult.failed;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String? ?? '').replaceFirst('v', '');
      final assets = (j['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
      final apk = assets.cast<Map<String, dynamic>?>().firstWhere((a) => (a!['name'] as String).endsWith('.apk'), orElse: () => null);
      if (apk == null) return UpdateResult.failed;
      final latest = _parse(tag);
      final mine = _parse('${info.version}+${info.buildNumber}');
      if (!_newer(latest, mine)) return UpdateResult.upToDate;
      if (!context.mounted) return UpdateResult.failed;
      await _ask(context, tag, apk['browser_download_url'] as String, (j['body'] as String? ?? '').trim(), j['html_url'] as String? ?? '');
      return UpdateResult.shown;
    } catch (_) {
      return UpdateResult.failed;
    }
  }

  /// 현재 설치된 버전 문자열 (설정 화면 표시용)
  static Future<String> currentVersion() async {
    try {
      final i = await PackageInfo.fromPlatform();
      return '${i.version}+${i.buildNumber}';
    } catch (_) {
      return '1.0.0';
    }
  }

  /// "1.2.3+45" → [1,2,3,45]
  static List<int> _parse(String v) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?').firstMatch(v);
    if (m == null) return [0, 0, 0, 0];
    return [for (var i = 1; i <= 4; i++) int.tryParse(m.group(i) ?? '0') ?? 0];
  }

  static bool _newer(List<int> a, List<int> b) {
    for (var i = 0; i < 4; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static Future<void> _ask(BuildContext context, String version, String url, String notes, String page) {
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(Mascot.face, width: 40, height: 40, fit: BoxFit.cover)),
            const SizedBox(width: 10),
            const Expanded(child: Text('새 버전이 나왔어요')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('메디텀 $version', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(height: 8),
            if (notes.isNotEmpty) Text(notes, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft)),
            const SizedBox(height: 8),
            const Text('「다운로드」를 누르면 APK 를 받아요. 받은 파일을 열면 바로 덮어 설치돼요.', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('나중에')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(c);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('다운로드'),
          ),
        ],
      ),
    );
  }
}
