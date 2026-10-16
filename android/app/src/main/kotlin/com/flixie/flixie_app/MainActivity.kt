package com.flixie.app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flixie/app_icon")
            .setMethodCallHandler { call, result ->
                val normal = ComponentName(this, "$packageName.DefaultIcon")
                val pip = ComponentName(this, "$packageName.PipGlassesIcon")
                val hoodie = ComponentName(this, "$packageName.PipHoodieIcon")
                val icons = mapOf("default" to normal, "pipGlasses" to pip, "pipHoodie" to hoodie)
                when (call.method) {
                    "status" -> result.success(mapOf(
                        "supported" to true,
                        "selected" to (icons.entries.firstOrNull { (_, component) ->
                            packageManager.getComponentEnabledSetting(component) ==
                                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        }?.key ?: "default")))
                    "set" -> {
                        val name = call.arguments as? String
                        val target = icons[name]
                        if (target == null) {
                            result.error("ICON_UNAVAILABLE", "Unknown app icon", null)
                        } else {
                            try {
                                packageManager.setComponentEnabledSetting(target,
                                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                                icons.values.filter { it != target }.forEach { previous ->
                                    packageManager.setComponentEnabledSetting(previous,
                                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                                }
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("ICON_FAILED", "Could not change app icon", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
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
