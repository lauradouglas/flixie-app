package com.flixie.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import android.view.View

/** Private debug-only host for inspecting actual RemoteViews, never in releases. */
class WidgetPreviewActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(28), dp(16), dp(16))
            setBackgroundColor(android.graphics.Color.rgb(57, 50, 70))
        }
        root.addView(TextView(this).apply { text = "Flixie widgets · device preview"; textSize = 18f; setTextColor(-1) },
            LinearLayout.LayoutParams(-1, dp(48)))
        val width = resources.displayMetrics.widthPixels / resources.displayMetrics.density - 32
        val wide = Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width.toInt())
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        }
        val small = Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 150)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 150)
        }
        fun add(view: View, w: Int, h: Int) {
            root.addView(view, LinearLayout.LayoutParams(w, h).apply { bottomMargin = dp(16) })
        }
        add(FlixieWatchlistWidget().views(this, wide).apply(this, root), -1, dp(180))
        add(FlixieWatchlistWidget().views(this, small).apply(this, root), dp(150), dp(150))
        add(FlixieSearchWidget().views(this).apply(this, root), dp(150), dp(150))
        setContentView(root)
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
