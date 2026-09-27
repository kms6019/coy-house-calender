package com.example.test_calender

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * APK 를 PackageInstaller 세션으로 설치한다.
 *
 * 안드로이드 12+ 에서는 이 앱이 자기 자신을 설치한 앱(installer of record)이면
 * USER_ACTION_NOT_REQUIRED 로 확인 창 없이 업데이트된다. 브라우저로 처음 설치한
 * 상태라면 첫 번째만 확인 창이 뜨고, 그 뒤로는 이 앱이 설치자가 된다.
 */
object AppUpdater {
    private const val CHANNEL = "coyhouse/updater"
    private const val TAG = "AppUpdater"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallSilently" -> result.success(canInstallSilently(app))
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "path 가 필요합니다.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        install(app, File(path))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message ?: e.javaClass.simpleName, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallSilently(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        if (!context.packageManager.canRequestPackageInstalls()) return false
        return try {
            val source = context.packageManager.getInstallSourceInfo(context.packageName)
            source.installingPackageName == context.packageName
        } catch (e: Exception) {
            false
        }
    }

    private fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(context.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("base.apk", 0, apk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val intent = Intent(context, UpdateStatusReceiver::class.java)
            // 시스템이 결과(EXTRA_STATUS 등)를 채워 넣어야 하므로 MUTABLE
            val pending = PendingIntent.getBroadcast(
                context,
                sessionId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            session.commit(pending.intentSender)
        }
        Log.i(TAG, "설치 세션 커밋: $sessionId")
    }
}

/** 설치 결과. 확인이 필요하면(첫 업데이트) 시스템 확인 화면을 띄운다. */
class UpdateStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                confirm?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                confirm?.let { context.startActivity(it) }
            }
            PackageInstaller.STATUS_SUCCESS -> Log.i("AppUpdater", "업데이트 설치 완료")
            else -> Log.w(
                "AppUpdater",
                "업데이트 실패($status): ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}",
            )
        }
    }
}
