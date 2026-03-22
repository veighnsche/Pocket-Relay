package me.vinch.pocketrelay

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val BACKGROUND_EXECUTION_CHANNEL =
            "me.vinch.pocketrelay/background_execution"
    }
}
