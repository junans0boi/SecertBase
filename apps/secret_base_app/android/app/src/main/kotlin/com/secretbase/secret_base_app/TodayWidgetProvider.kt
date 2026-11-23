package com.secretbase.secret_base_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 기지 위젯 ② 오늘 서로 남긴 것: 마주 열기 상태, 오늘의 루프, 안 읽은 쪽지 수(숫자만). */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val v = BaseWidgetValues(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setOnClickPendingIntent(R.id.widget_root, BaseWidgetIntents.open(context, "home"))
            views.setOnClickPendingIntent(R.id.row_qa, BaseWidgetIntents.open(context, "two_answers"))
            views.setOnClickPendingIntent(R.id.row_notes, BaseWidgetIntents.open(context, "notes"))
            if (!v.active) {
                views.setViewVisibility(R.id.today_rows, View.GONE)
                views.setViewVisibility(R.id.today_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.today_rows, View.VISIBLE)
                views.setViewVisibility(R.id.today_empty, View.GONE)
                views.setTextViewText(
                    R.id.qa_value,
                    context.getString(
                        when (v.qaState) {
                            "my_turn" -> R.string.widget_qa_my_turn
                            "waiting" -> R.string.widget_qa_waiting
                            "open" -> R.string.widget_qa_open
                            else -> R.string.widget_unknown
                        }
                    ),
                )
                views.setTextViewText(
                    R.id.loop_value,
                    context.getString(
                        when (v.loopOpen) {
                            1 -> R.string.widget_loop_open
                            0 -> R.string.widget_loop_closed
                            else -> R.string.widget_unknown
                        }
                    ),
                )
                views.setTextViewText(
                    R.id.notes_value,
                    if (v.unread > 0) context.getString(R.string.widget_notes_count, v.unread)
                    else context.getString(R.string.widget_notes_none),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
