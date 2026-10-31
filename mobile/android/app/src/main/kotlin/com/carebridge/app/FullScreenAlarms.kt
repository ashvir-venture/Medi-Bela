package com.carebridge.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import org.json.JSONObject

/**
 * Full-screen reminders over other apps (owner, 2026-10-31).
 *
 * The Dart side (lib/notifications/full_screen_alarms.dart) keeps the
 * upcoming ringing reminders in SharedPreferences as
 * `{"<notification id>": {"at": <ms>, "route": "/reminder?..."}}`, from any
 * isolate. [sync] schedules one AlarmManager alarm per entry; when it fires,
 * [ReminderAlarmReceiver] opens MainActivity on that route if the user
 * allowed "Display over other apps" (which also lets the app start an
 * activity from the background). Without it nothing opens here: the ringing
 * notification's full-screen intent covers a locked phone, the banner the
 * rest. A cancelled reminder is gone from the list, so a stale alarm does
 * nothing.
 */
object FullScreenAlarms {
    const val ACTION_FIRE = "com.carebridge.app.FULL_SCREEN_ALARM"
    const val ACTION_SHOW = "com.carebridge.app.SHOW_REMINDER"
    const val EXTRA_ID = "id"
    const val EXTRA_ROUTE = "route"

    // shared_preferences (legacy API) file and key prefix.
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.fullscreen_alarms"
    private const val OWN_PREFS = "medibela_full_screen"
    private const val SCHEDULED = "scheduled"

    /** An alarm firing later than this after its time (phone was off) opens nothing. */
    private const val STALE_MS = 30 * 60_000L

    fun canDrawOverlays(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    private fun entries(context: Context): JSONObject {
        val raw = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getString(KEY, null)
        return try {
            if (raw.isNullOrEmpty()) JSONObject() else JSONObject(raw)
        } catch (e: Exception) {
            JSONObject()
        }
    }

    private fun pending(context: Context, id: Int, create: Boolean): PendingIntent? {
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_ID, id)
        val flags = PendingIntent.FLAG_IMMUTABLE or
            if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE
        return PendingIntent.getBroadcast(context, id, intent, flags)
    }

    /** Makes the OS alarms match the stored list (adds, moves, removes). */
    fun sync(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val own = context.getSharedPreferences(OWN_PREFS, Context.MODE_PRIVATE)
        val before = own.getStringSet(SCHEDULED, emptySet()) ?: emptySet()
        val list = entries(context)
        val now = System.currentTimeMillis()
        val scheduled = mutableSetOf<String>()

        for (key in list.keys()) {
            val entry = list.optJSONObject(key) ?: continue
            val at = entry.optLong("at")
            val id = key.toIntOrNull() ?: continue
            if (at <= now) continue
            val intent = pending(context, id, true) ?: continue
            val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
            if (exact) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            }
            scheduled.add(key)
        }
        for (key in before - scheduled) {
            val id = key.toIntOrNull() ?: continue
            pending(context, id, false)?.let {
                alarms.cancel(it)
                it.cancel()
            }
        }
        own.edit().putStringSet(SCHEDULED, scheduled).apply()
    }

    /** The route to open for alarm [id], or null when cancelled or stale. */
    fun routeFor(context: Context, id: Int): String? {
        val entry = entries(context).optJSONObject(id.toString()) ?: return null
        val at = entry.optLong("at")
        if (System.currentTimeMillis() - at > STALE_MS) return null
        return entry.optString("route").ifEmpty { null }
    }
}

/** Fires a full-screen reminder; also re-registers the alarms after a reboot or update. */
class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == FullScreenAlarms.ACTION_FIRE) {
            val route = FullScreenAlarms.routeFor(context, intent.getIntExtra(FullScreenAlarms.EXTRA_ID, -1))
            if (route != null && FullScreenAlarms.canDrawOverlays(context)) {
                val show = Intent(context, MainActivity::class.java)
                    .setAction(FullScreenAlarms.ACTION_SHOW)
                    .putExtra(FullScreenAlarms.EXTRA_ROUTE, route)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                try {
                    context.startActivity(show)
                } catch (e: Exception) {
                    // Not allowed right now: the ringing banner is still there.
                }
            }
        }
        FullScreenAlarms.sync(context)
    }
}
