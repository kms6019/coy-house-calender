import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// 배포된 최신 버전 정보 (hosting_public/version.json)
class UpdateInfo {
  final int buildNumber;
  final String versionName;
  final String apkUrl;
  final String notes;

  const UpdateInfo({
    required this.buildNumber,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
  });

  static UpdateInfo? fromJson(Map<String, dynamic> json) {
    final build = json['buildNumber'];
    final url = json['apkUrl'] as String? ?? '';
    if (build is! int || url.isEmpty) return null;
    return UpdateInfo(
      buildNumber: build,
      versionName: json['versionName'] as String? ?? '',
      apkUrl: url,
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }
}

/// 앱 실행 시 새 버전을 확인하고 APK를 받아 설치 화면까지 띄운다.
///
/// 안드로이드는 앱이 스스로 조용히 설치할 수 없다(시스템 권한 필요). 여기까지가
/// 사이드로딩 배포에서 가능한 최선이고, 마지막 설치 확인은 사용자가 눌러야 한다.
class UpdateService {
  static const _manifestUrl =
      'https://coy-house-calender.web.app/version.json';

  /// 이번 실행에서 이미 물어봤는지 — 화면 전환마다 다시 뜨는 걸 막는다.
  static bool _askedThisSession = false;

  final http.Client _client;
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// 새 버전이 있으면 정보를, 없으면 null. 네트워크 실패도 null.
  Future<UpdateInfo?> check({bool force = false}) async {
    if (!_supported) return null;
    if (_askedThisSession && !force) return null;

    try {
      final response = await _client
          .get(Uri.parse('$_manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final info = UpdateInfo.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (info == null) return null;

      final current = int.tryParse((await PackageInfo.fromPlatform()).buildNumber);
      if (current == null || info.buildNumber <= current) return null;

      _askedThisSession = true;
      return info;
    } catch (_) {
      return null; // 오프라인 등 — 다음 실행에 다시 시도
    }
  }

  /// APK를 내려받는다. [onProgress]는 0.0~1.0 (길이를 모르면 호출되지 않음).
  Future<File> download(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/coyhouse-${info.buildNumber}.apk');
    if (await file.exists()) await file.delete();

    final response = await _client.send(
      http.Request('GET', Uri.parse(info.apkUrl)),
    );
    if (response.statusCode != 200) {
      throw HttpException('다운로드 실패 (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// 설치 화면을 띄운다. "출처를 알 수 없는 앱" 허용이 필요할 수 있다.
  Future<void> install(File apk) async {
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
