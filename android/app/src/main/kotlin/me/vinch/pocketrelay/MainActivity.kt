package me.vinch.pocketrelay

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_EXECUTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setActiveTurnForegroundServiceEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error(
                            "invalid-arguments",
                            "Expected a boolean enabled flag.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    if (enabled) {
                        ActiveTurnForegroundService.start(applicationContext)
                    } else {
                        ActiveTurnForegroundService.stop(applicationContext)
                    }
                    result.success(null)
                }

                "notificationsPermissionGranted" -> {
                    result.success(isNotificationPermissionGranted())
                }

                "requestNotificationPermission" -> {
                    if (pendingNotificationPermissionResult != null) {
                        result.error(
                            "request-in-progress",
                            "A notification permission request is already active.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    if (isNotificationPermissionGranted()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    pendingNotificationPermissionResult = result
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        POST_NOTIFICATIONS_PERMISSION_REQUEST_CODE,
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != POST_NOTIFICATIONS_PERMISSION_REQUEST_CODE) {
            return
        }

        val granted =
            grantResults.any { result -> result == PackageManager.PERMISSION_GRANTED }
        pendingNotificationPermissionResult?.success(granted)
        pendingNotificationPermissionResult = null
    }

    private fun isNotificationPermissionGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }

        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val BACKGROUND_EXECUTION_CHANNEL =
            "me.vinch.pocketrelay/background_execution"
        private const val POST_NOTIFICATIONS_PERMISSION_REQUEST_CODE = 1001
    }
}
