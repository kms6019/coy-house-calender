import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// 앱 실행 시 새 버전이 있으면 한 번 물어본다. 결과는 무시해도 되는 fire-and-forget.
Future<void> maybePromptUpdate(BuildContext context) async {
  final service = UpdateService();
  final info = await service.check();
  if (info == null || !context.mounted) return;

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

  if (accepted != true || !context.mounted) return;
  await _downloadAndInstall(context, service, info);
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
