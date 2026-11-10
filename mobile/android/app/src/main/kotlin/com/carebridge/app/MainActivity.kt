package com.carebridge.app

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the "reminder_status" channel used by the Reminder check screen for
 * the checks flutter_local_notifications doesn't cover: whether the reminders
 * channel was switched off, whether battery optimization may delay reminders,
 * and opening the matching system settings pages (incl. the medicine alarm
 * channel's own page, where the user picks the reminder sound).
 *
 * Round 13: full-screen reminders. The activity shows over the lock screen
 * only while a reminder opened it (a full-screen alarm, or the notification's
 * full-screen intent on a locked phone); `finishAlarm` turns that off again
 * and returns to whatever was on screen before. Routes from alarms reach
 * Flutter through `openRoute` / `takeLaunchRoute`.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var launchRoute: String? = null
    private var launchedForAlarm = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyAlarmWindow(intent)
        FullScreenAlarms.sync(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyAlarmWindow(intent)
        val route = intent.getStringExtra(FullScreenAlarms.EXTRA_ROUTE)
        if (intent.action == FullScreenAlarms.ACTION_SHOW && route != null) {
            channel?.invokeMethod("openRoute", route)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.carebridge.app/reminder_status")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "isChannelBlocked" -> result.success(isChannelBlocked(call.argument<String>("channelId")))
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "openNotificationSettings" -> result.success(openNotificationSettings())
                "openBatterySettings" -> result.success(openBatterySettings())
                "openChannelSettings" -> result.success(openChannelSettings(call.argument<String>("channelId")))
                "canDrawOverlays" -> result.success(FullScreenAlarms.canDrawOverlays(this))
                "openOverlaySettings" -> result.success(openOverlaySettings())
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                "syncFullScreenAlarms" -> {
                    FullScreenAlarms.sync(this)
                    result.success(true)
                }
                "takeLaunchRoute" -> {
                    result.success(launchRoute)
                    launchRoute = null
                }
                "finishAlarm" -> result.success(finishAlarm())
                // Round 14: phone-brand steps on Reminder check.
                "deviceBrand" -> result.success(android.os.Build.MANUFACTURER ?: "")
                "openAppSettings" -> result.success(
                    launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))),
                )
                else -> result.notImplemented()
            }
        }
    }

    /** Over the lock screen, screen on: only when a reminder opened the app. */
    private fun applyAlarmWindow(intent: Intent?) {
        if (intent == null) return
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val fromAlarm = intent.action == FullScreenAlarms.ACTION_SHOW
        // The notification's full-screen intent on a locked or dark phone.
        val fromFullScreenIntent = intent.action == "SELECT_NOTIFICATION" &&
            (keyguard.isKeyguardLocked || !power.isInteractive)
        if (!fromAlarm && !fromFullScreenIntent) return
        launchedForAlarm = true
        if (fromAlarm) launchRoute = intent.getStringExtra(FullScreenAlarms.EXTRA_ROUTE)
        setOverLockScreen(true)
    }

    @Suppress("DEPRECATION")
    private fun setOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    /** After Taken / Later: back behind the lock screen or to the app that was open. */
    private fun finishAlarm(): Boolean {
        if (!launchedForAlarm) return false
        launchedForAlarm = false
        setOverLockScreen(false)
        moveTaskToBack(true)
        return true
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

    /** Android 14+ asks the user for full-screen notifications; older phones allow them. */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun openOverlaySettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return launch(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))) ||
            launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
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

    // One channel's own page (sound, vibration). Android 8+; older phones get
    // the app's notification settings.
    private fun openChannelSettings(channelId: String?): Boolean {
        if (channelId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return openNotificationSettings()
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        return launch(intent) || openNotificationSettings()
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
