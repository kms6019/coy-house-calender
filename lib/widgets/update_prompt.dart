import 'dart:io';

import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// 앱 실행 시 새 버전이 있으면 한 번 물어본다. 결과는 무시해도 되는 fire-and-forget.
Future<void> maybePromptUpdate(BuildContext context) async {
  final service = UpdateService();
  final info = await service.check();
  if (info == null || !context.mounted) return;

  if (await service.canInstallSilently()) {
    if (context.mounted) await _installQuietly(context, service, info);
    return;
  }
  if (!context.mounted) return;

  if (await _confirmUpdate(context, info) && context.mounted) {
    await _downloadAndInstall(context, service, info);
  }
}

/// 설정의 "업데이트 확인" 버튼. 결과를 항상 알려 주고, 새 버전이면 화면을 띄운 채
/// 받아서 설치한다 — 앱이 화면에 있을 때 설치해야 확인 창이 막히지 않는다.
Future<void> checkForUpdateManually(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = UpdateService();
  final UpdateInfo latest;
  final int? current;
  try {
    latest = await service.fetchLatest();
    current = await UpdateService.currentBuild();
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('업데이트를 확인하지 못했어요. 인터넷 연결을 확인해 주세요.')),
    );
    return;
  }
  if (current != null && latest.buildNumber <= current) {
    messenger.showSnackBar(
      SnackBar(content: Text('최신 버전이에요 (${latest.versionName})')),
    );
    return;
  }
  if (!context.mounted) return;
  if (await _confirmUpdate(context, latest) && context.mounted) {
    await _downloadAndInstall(context, service, latest);
  }
}

Future<bool> _confirmUpdate(BuildContext context, UpdateInfo info) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('새 버전이 있어요'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('버전 ${info.versionName}'),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              info.notes,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('지금 업데이트'),
        ),
      ],
    ),
  );
  return accepted == true;
}

Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateInfo info,
) async {
  final progress = ValueNotifier<double>(0);
  var closed = false;

  void closeSheet() {
    if (closed) return;
    closed = true;
    Navigator.of(context, rootNavigator: true).pop();
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('내려받는 중'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value == 0 ? null : value),
              const SizedBox(height: 12),
              Text(value == 0 ? '연결 중…' : '${(value * 100).round()}%'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final apk = await service.download(
      info,
      onProgress: (value) => progress.value = value,
    );
    closeSheet();
    await service.install(apk);
  } catch (error) {
    closeSheet();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('업데이트 실패: $error')),
    );
  } finally {
    progress.dispose();
  }
}

/// 설치 대기 중인 앱 생명주기 리스너 — 설치 후엔 앱이 교체되므로 해제할 일이 없다.
AppLifecycleListener? _pendingInstall;

/// 확인 창 없이 설치할 수 있을 때: 조용히 받아 두고, 앱을 떠나는 순간 설치한다.
/// 쓰는 도중에 앱이 꺼지지 않도록 설치는 화면을 벗어났을 때만 한다.
Future<void> _installQuietly(
  BuildContext context,
  UpdateService service,
  UpdateInfo info,
) async {
  final File apk;
  try {
    apk = await service.download(info);
  } catch (e) {
    debugPrint('[Update] 백그라운드 다운로드 실패: $e');
    return; // 다음 실행 때 다시 시도
  }

  Future<void> installNow() async {
    try {
      await service.install(apk);
    } catch (e) {
      debugPrint('[Update] 자동 설치 실패: $e');
    }
  }

  final state = WidgetsBinding.instance.lifecycleState;
  if (state != null && state != AppLifecycleState.resumed) {
    await installNow();
    return;
  }

  _pendingInstall ??= AppLifecycleListener(onHide: installNow);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('새 버전 ${info.versionName}을 받아 두었어요. 앱을 닫으면 업데이트돼요.'),
    ),
  );
}
