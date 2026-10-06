package com.flixie.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.View
import android.widget.RemoteViews

internal fun widgetIntent(context: Context, watchlist: Boolean): PendingIntent {
    val destination = if (watchlist) "flixie:///watchlist" else "flixie:///search?focus=1"
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(destination), context, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    return PendingIntent.getActivity(context, if (watchlist) 41 else 42, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}

private fun wordmark(): CharSequence = SpannableString("flixie").apply {
    setSpan(ForegroundColorSpan(Color.rgb(124, 77, 255)), 4, 6, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
}

class FlixieSearchWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context)) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        manager.updateAppWidget(id, views(context))
    }
    internal fun views(context: Context) = RemoteViews(context.packageName, R.layout.flixie_search_widget).apply {
        setTextViewText(R.id.widget_wordmark, wordmark())
        setOnClickPendingIntent(R.id.widget_root, widgetIntent(context, false))
    }
}

class FlixieWatchlistWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context, manager.getAppWidgetOptions(it))) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        manager.updateAppWidget(id, views(context, options))
    }

    internal fun views(context: Context, options: Bundle): RemoteViews {
        val snapshot = FlixieWidgetStore.read(context)
        val items = snapshot.optJSONArray("items") ?: org.json.JSONArray()
        // Leave enough height for enlarged text; a narrow widget remains a launcher.
        val wide = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 240 &&
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= 130
        return RemoteViews(context.packageName, R.layout.flixie_watchlist_widget).apply {
            setTextViewText(R.id.widget_wordmark, wordmark())
            setOnClickPendingIntent(R.id.widget_root, widgetIntent(context, true))
            setViewVisibility(R.id.widget_watchlist_label, if (wide) View.VISIBLE else View.GONE)
            val showPosters = wide && items.length() > 0
            setViewVisibility(R.id.widget_posters, if (showPosters) View.VISIBLE else View.GONE)
            setViewVisibility(R.id.widget_message, if (showPosters) View.GONE else View.VISIBLE)
            setTextViewText(R.id.widget_message, if (!snapshot.optBoolean("signedIn")) context.getString(if (wide) R.string.widget_sign_in else R.string.widget_compact_sign_in)
                else if (items.length() == 0) context.getString(if (wide) R.string.widget_empty else R.string.widget_compact_empty)
                else context.getString(R.string.widget_watchlist_action))
            val slots = arrayOf(
                intArrayOf(R.id.widget_slot_0, R.id.widget_poster_0, R.id.widget_title_0),
                intArrayOf(R.id.widget_slot_1, R.id.widget_poster_1, R.id.widget_title_1),
                intArrayOf(R.id.widget_slot_2, R.id.widget_poster_2, R.id.widget_title_2),
                intArrayOf(R.id.widget_slot_3, R.id.widget_poster_3, R.id.widget_title_3))
            slots.forEachIndexed { index, ids ->
                val item = items.optJSONObject(index)
                setViewVisibility(ids[0], if (item != null) View.VISIBLE else View.INVISIBLE)
                setImageViewBitmap(ids[1], null)
                val poster = item?.let { FlixieWidgetStore.poster(context, it) }
                setViewVisibility(ids[1], if (poster != null) View.VISIBLE else View.GONE)
                setViewVisibility(ids[2], if (poster == null) View.VISIBLE else View.GONE)
                setTextViewText(ids[2], item?.optString("title") ?: "")
                setContentDescription(ids[0], item?.optString("title") ?: "")
                if (poster != null) setImageViewBitmap(ids[1], poster)
            }
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FlixieWatchlistWidget::class.java))
            if (ids.isNotEmpty()) FlixieWatchlistWidget().onUpdate(context, manager, ids)
        }
    }
}
