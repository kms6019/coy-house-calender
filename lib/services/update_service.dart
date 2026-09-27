import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// 앱 실행 시 새 버전을 확인하고 APK를 받아 설치한다.
///
/// 설치는 네이티브 PackageInstaller 세션(AppUpdater.kt)으로 한다. 안드로이드 12+
/// 에서 이 앱이 자기 자신의 설치자면 확인 창 없이 업데이트되고, 브라우저로 처음
/// 설치한 상태라면 첫 한 번만 확인 창이 뜬다.
class UpdateService {
  static const _manifestUrl =
      'https://coy-house-calender.web.app/version.json';
  static const _channel = MethodChannel('coyhouse/updater');

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

  /// 확인 창 없이 설치할 수 있는 상태인지 (안드로이드 12+ 이고 설치자가 이 앱).
  Future<bool> canInstallSilently() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstallSilently') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 네이티브 세션으로 설치한다. 실패하면 예전 방식(설치 화면 열기)으로 넘어간다.
  /// "출처를 알 수 없는 앱" 허용이 필요할 수 있다.
  Future<void> install(File apk) async {
    try {
      await _channel.invokeMethod<bool>('install', {'path': apk.path});
      return;
    } catch (e) {
      debugPrint('[UpdateService] 세션 설치 실패, 설치 화면으로 대체: $e');
    }
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
