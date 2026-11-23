package com.secretbase.secret_base_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 기지 위젯 ① D-day와 다음 기념일. */
class DdayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val v = BaseWidgetValues(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_dday)
            views.setOnClickPendingIntent(R.id.widget_root, BaseWidgetIntents.open(context, "home"))
            val dDay = v.dDay
            if (!v.active || dDay == null) {
                views.setTextViewText(R.id.dday_caption, context.getString(R.string.widget_dday_caption))
                views.setTextViewText(R.id.dday_value, context.getString(R.string.widget_empty_title))
                views.setTextViewText(R.id.dday_next, context.getString(R.string.widget_empty_hint))
            } else {
                views.setTextViewText(R.id.dday_caption, context.getString(R.string.widget_dday_caption))
                views.setTextViewText(R.id.dday_value, "D+$dDay")
                val days = v.annDays
                if (v.annLabel.isNotEmpty() && days != null) {
                    val whenText = if (days == 0) context.getString(R.string.widget_today)
                    else context.getString(R.string.widget_days_left, days)
                    views.setTextViewText(R.id.dday_next, "${v.annLabel} · $whenText")
                    views.setViewVisibility(R.id.dday_next, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.dday_next, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
