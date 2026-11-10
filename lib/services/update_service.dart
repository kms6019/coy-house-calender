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

  /// 빌드마다 다른 다운로드 주소. 배포 직후 CDN 엣지가 옛 APK 를 잠깐 돌려주는
  /// 일이 있어서 캐시 키를 빌드 번호로 가른다.
  static Uri apkDownloadUri(UpdateInfo info) {
    final uri = Uri.parse(info.apkUrl);
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'v': '${info.buildNumber}'},
    );
  }

  /// APK 다운로드 요청. 압축 없이 받는다 — 서버가 gzip 으로 주면 dart:io 가
  /// 알아서 풀면서도 Content-Length 는 압축된 크기(절반 남짓)를 그대로 알려 줘서
  /// 진행률이 200% 를 넘고 아래 길이 검사에 걸린다.
  static http.Request apkRequest(UpdateInfo info) =>
      http.Request('GET', apkDownloadUri(info))
        ..headers['Accept-Encoding'] = 'identity';

  /// APK를 내려받는다. [onProgress]는 0.0~1.0 (길이를 모르면 호출되지 않음).
  ///
  /// 받는 중에는 `.part` 파일에 쓰고 다 받은 뒤에 이름을 바꾼다. 완성된 파일은
  /// 다시 받지 않되, 실제 버전이 [info] 와 다르면(옛 APK 를 받아 둔 경우) 버린다.
  Future<File> download(
    UpdateInfo info, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/coyhouse-${info.buildNumber}.apk');
    if (await file.exists()) {
      if (await _isBuild(file, info.buildNumber)) return file;
      await file.delete();
    }
    final part = File('${file.path}.part');

    final response = await _client.send(apkRequest(info));
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
    final done = await part.rename(file.path);
    if (!await _isBuild(done, info.buildNumber)) {
      await done.delete();
      throw const HttpException('받은 파일이 새 버전이 아니에요. 잠시 후 다시 시도해 주세요.');
    }
    return done;
  }

  /// APK 의 versionCode 가 [build] 인지. 읽지 못하면 막지 않는다.
  Future<bool> _isBuild(File apk, int build) async {
    try {
      final code = await _channel.invokeMethod<int>('apkVersionCode', {
        'path': apk.path,
      });
      return code == null || code == build;
    } catch (_) {
      return true;
    }
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
