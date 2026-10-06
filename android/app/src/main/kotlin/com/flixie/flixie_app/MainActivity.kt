package com.flixie.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flixie/watchlist_widget")
            .setMethodCallHandler { call, result ->
                if (call.method != "sync") {
                    result.notImplemented()
                } else {
                    try {
                        FlixieWidgetStore.sync(applicationContext, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("WIDGET_SYNC_FAILED", "Your widget could not refresh. Open Flixie to try again.", null)
                    }
                }
            }
    }
}
