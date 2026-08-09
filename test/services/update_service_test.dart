import 'package:coy_house_calender/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
