package com.carebridge.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the "reminder_status" channel used by the Reminder check screen for
 * the checks flutter_local_notifications doesn't cover: whether the reminders
 * channel was switched off, whether battery optimization may delay reminders,
 * and opening the matching system settings pages.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.carebridge.app/reminder_status")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isChannelBlocked" -> result.success(isChannelBlocked(call.argument<String>("channelId")))
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    "openBatterySettings" -> result.success(openBatterySettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun isChannelBlocked(channelId: String?): Boolean {
        if (channelId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // A channel that doesn't exist yet is created on the first schedule.
        val channel = manager.getNotificationChannel(channelId) ?: return false
        return channel.importance == NotificationManager.IMPORTANCE_NONE
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        return launch(intent)
    }

    // The list screen needs no special permission (unlike the direct
    // "ignore optimizations" prompt, which Play restricts).
    private fun openBatterySettings(): Boolean =
        launch(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
            launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))

    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }
}
