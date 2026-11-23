package com.secretbase.secret_base_app

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.app.PendingIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** 기지 위젯이 읽는 값. 앱(Dart)이 숫자·상태 코드·짧은 기념일 이름만 써 둔다. */
class BaseWidgetValues(prefs: SharedPreferences) {
    private val all = prefs.all

    private fun int(key: String, fallback: Int): Int =
        (all[key] as? Number)?.toInt() ?: fallback

    val active: Boolean = all["active"] as? Boolean ?: false
    val qaState: String = all["qa_state"] as? String ?: "unknown"
    val loopOpen: Int = int("loop_open", -1)
    val unread: Int = int("unread", 0)
    val annLabel: String = all["ann_label"] as? String ?: ""

    // 앱을 열지 않은 날에도 하루씩 이어서 센다.
    private val elapsedDays: Long = run {
        val asOf = all["as_of"] as? String ?: return@run 0L
        try {
            ChronoUnit.DAYS.between(LocalDate.parse(asOf), LocalDate.now()).coerceAtLeast(0)
        } catch (e: Exception) {
            0L
        }
    }

    val dDay: Int? = int("dday", -1).takeIf { it >= 0 }?.let { (it + elapsedDays).toInt() }
    val annDays: Int? = int("ann_days", -1).takeIf { it >= 0 }
        ?.let { (it - elapsedDays).toInt() }?.takeIf { it >= 0 }
}

object BaseWidgetIntents {
    fun open(context: Context, target: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("secretbase://widget/$target"),
        )
}
