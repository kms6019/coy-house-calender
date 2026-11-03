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

  /// 배포된 최신 버전 정보. 네트워크·형식 오류는 예외로 올린다
  /// ("업데이트 확인" 버튼이 "최신 버전"과 "확인 실패"를 구분해야 해서).
  Future<UpdateInfo> fetchLatest() async {
    final response = await _client
        .get(Uri.parse('$_manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw HttpException('버전 정보 응답 ${response.statusCode}');
    }
    final info = UpdateInfo.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
    if (info == null) throw const FormatException('버전 정보 형식 오류');
    return info;
  }

  /// 설치된 앱의 빌드 번호 (pubspec 의 +N)
  static Future<int?> currentBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber);

  /// 새 버전이 있으면 정보를, 없으면 null. 네트워크 실패도 null.
  Future<UpdateInfo?> check({bool force = false}) async {
    if (!_supported) return null;
    if (_askedThisSession && !force) return null;

    try {
      final info = await fetchLatest();
      final current = await currentBuild();
      if (current == null || info.buildNumber <= current) return null;

      _askedThisSession = true;
      return info;
    } catch (_) {
      return null; // 오프라인 등 — 다음 실행에 다시 시도
    }
  }

  /// APK를 내려받는다. [onProgress]는 0.0~1.0 (길이를 모르면 호출되지 않음).
  ///
  /// 받는 중에는 `.part` 파일에 쓰고 다 받은 뒤에 이름을 바꾼다. 그래서 완성된
  /// 파일이 있으면 다시 받지 않는다 — 받는 도중 앱을 닫아 끊기면 처음부터 다시.
  Future<File> download(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/coyhouse-${info.buildNumber}.apk');
    if (await file.exists()) return file;
    final part = File('${file.path}.part');

    final response = await _client.send(
      http.Request('GET', Uri.parse(info.apkUrl)),
    );
    if (response.statusCode != 200) {
      throw HttpException('다운로드 실패 (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      throw HttpException('다운로드가 중간에 끊겼어요 ($received/$total)');
    }
    return part.rename(file.path);
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
