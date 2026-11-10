import 'dart:convert';
import 'dart:io';

import 'package:coy_house_calender/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('UpdateInfo.fromJson', () {
    test('정상 매니페스트를 파싱한다', () {
      final info = UpdateInfo.fromJson({
        'buildNumber': 7,
        'versionName': '1.0.6',
        'apkUrl': 'https://example.com/app.apk',
        'notes': '  알람 수정  ',
      });
      expect(info, isNotNull);
      expect(info!.buildNumber, 7);
      expect(info.versionName, '1.0.6');
      expect(info.apkUrl, 'https://example.com/app.apk');
      expect(info.notes, '알람 수정');
    });

    test('buildNumber 가 숫자가 아니면 null', () {
      expect(
        UpdateInfo.fromJson({
          'buildNumber': '7',
          'apkUrl': 'https://example.com/app.apk',
        }),
        isNull,
      );
    });

    test('apkUrl 이 없으면 null', () {
      expect(UpdateInfo.fromJson({'buildNumber': 7}), isNull);
    });

    test('notes/versionName 이 없어도 파싱된다', () {
      final info = UpdateInfo.fromJson({
        'buildNumber': 2,
        'apkUrl': 'https://example.com/app.apk',
      });
      expect(info, isNotNull);
      expect(info!.notes, '');
      expect(info.versionName, '');
    });
  });

  group('fetchLatest', () {
    UpdateService serviceReturning(int status, Object body) => UpdateService(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(body is String ? body : jsonEncode(body)),
          status,
        ),
      ),
    );

    test('배포된 버전 정보를 돌려준다', () async {
      final info = await serviceReturning(200, {
        'buildNumber': 21,
        'versionName': '1.1.11',
        'apkUrl': 'https://example.com/app.apk',
        'notes': '업데이트 확인 버튼',
      }).fetchLatest();
      expect(info.buildNumber, 21);
      expect(info.notes, '업데이트 확인 버튼');
    });

    test('응답 실패는 null 이 아니라 예외 — "최신 버전"과 구분', () async {
      expect(
        serviceReturning(404, 'not found').fetchLatest(),
        throwsA(isA<HttpException>()),
      );
    });

    test('형식이 맞지 않으면 예외', () async {
      expect(
        serviceReturning(200, {'buildNumber': '21'}).fetchLatest(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('apkDownloadUri', () {
    UpdateInfo infoWith(String url) => UpdateInfo.fromJson({
      'buildNumber': 23,
      'apkUrl': url,
    })!;

    test('빌드 번호를 v 로 붙인다', () {
      final uri = UpdateService.apkDownloadUri(
        infoWith('https://example.com/app.apk'),
      );
      expect(uri.toString(), 'https://example.com/app.apk?v=23');
    });

    test('이미 v 가 있으면 빌드 번호로 맞추고 다른 값은 유지', () {
      final uri = UpdateService.apkDownloadUri(
        infoWith('https://example.com/app.apk?v=22&x=1'),
      );
      expect(uri.queryParameters, {'v': '23', 'x': '1'});
    });

    test('APK 는 압축 없이 요청한다 (진행률·길이 검사가 실제 크기 기준이 되게)', () {
      final request = UpdateService.apkRequest(
        infoWith('https://example.com/app.apk'),
      );
      expect(request.url.toString(), 'https://example.com/app.apk?v=23');
      expect(request.headers['Accept-Encoding'], 'identity');
    });
  });
}
