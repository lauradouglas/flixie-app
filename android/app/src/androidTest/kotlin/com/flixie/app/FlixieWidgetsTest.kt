package com.flixie.app

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Test

/** Isolated native checks: fictional snapshots only, no database or account login. */
class FlixieWidgetsTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private fun payload(account: String? = "fixture-alice", count: Int = 4) =
        mapOf("account" to account, "items" to (0 until count).map {
            mapOf("id" to "movie-$it", "title" to listOf("The Odyssey", "Alien", "Spider-Man", "Obsession", "Interstellar")[it % 5], "poster" to null)
        })
    private fun options(width: Int, height: Int = 150) = Bundle().apply {
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height)
    }
    @After fun clear() { FlixieWidgetStore.sync(context, payload(null, 0)) }

    @Test fun storesOnlyFourTitlesAndNoCredentials() {
        FlixieWidgetStore.sync(context, payload(count = 5) + ("token" to "fixture-secret"))
        val snapshot = FlixieWidgetStore.read(context)
        assertTrue(snapshot.getBoolean("signedIn"))
        assertEquals(4, snapshot.getJSONArray("items").length())
        assertFalse(snapshot.toString().contains("fixture-secret"))
        assertFalse(snapshot.toString().contains("fixture-alice"))
    }

    @Test fun accountChangeAndLogoutClearPostersAndRejectLateDownload() {
        FlixieWidgetStore.sync(context, payload())
        val old = FlixieWidgetStore.read(context)
        val bitmap = Bitmap.createBitmap(40, 60, Bitmap.Config.ARGB_8888)
        try {
            val item = old.getJSONArray("items").getJSONObject(0)
            assertTrue(FlixieWidgetStore.publishPoster(context, old.getString("revision"), item.getString("file"), bitmap))
            assertNotNull(FlixieWidgetStore.poster(context, item))
            FlixieWidgetStore.sync(context, payload("fixture-bob", 1))
            assertNull(FlixieWidgetStore.poster(context, item))
            assertFalse(FlixieWidgetStore.publishPoster(context, old.getString("revision"), item.getString("file"), bitmap))
            FlixieWidgetStore.sync(context, payload(null))
            assertFalse(FlixieWidgetStore.read(context).getBoolean("signedIn"))
            assertEquals(0, FlixieWidgetStore.read(context).getJSONArray("items").length())
        } finally { bitmap.recycle() }
    }

    @Test fun wideShowsFourFallbackTitlesAndNarrowReflowsToLauncher() {
        FlixieWidgetStore.sync(context, payload())
        instrumentation.runOnMainSync {
            val wide = FlixieWatchlistWidget().views(context, options(300)).apply(context, FrameLayout(context))
            assertEquals(View.VISIBLE, wide.findViewById<View>(R.id.widget_posters).visibility)
            assertEquals("The Odyssey", wide.findViewById<TextView>(R.id.widget_title_0).text.toString())
            assertEquals("Obsession", wide.findViewById<TextView>(R.id.widget_title_3).text.toString())
            assertEquals(View.GONE, wide.findViewById<ImageView>(R.id.widget_poster_0).visibility)
            val narrow = FlixieWatchlistWidget().views(context, options(140)).apply(context, FrameLayout(context))
            assertEquals(View.GONE, narrow.findViewById<View>(R.id.widget_posters).visibility)
            assertEquals(View.GONE, narrow.findViewById<View>(R.id.widget_watchlist_label).visibility)
            assertEquals("Watchlist", narrow.findViewById<TextView>(R.id.widget_message).text.toString())
        }
    }

    @Test fun compactAndWideTextFitsAtEnlargedSystemFont() {
        FlixieWidgetStore.sync(context, payload(null, 0))
        val config = android.content.res.Configuration(context.resources.configuration).apply { fontScale = 1.3f }
        val enlarged = context.createConfigurationContext(config)
        instrumentation.runOnMainSync {
            for (size in listOf(130 to 130, 300 to 150, 600 to 240)) {
                val view = FlixieWatchlistWidget().views(enlarged, options(size.first, size.second)).apply(enlarged, FrameLayout(enlarged))
                val density = enlarged.resources.displayMetrics.density
                val width = (size.first * density).toInt()
                val height = (size.second * density).toInt()
                view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                view.layout(0, 0, width, height)
                val message = view.findViewById<TextView>(R.id.widget_message)
                assertTrue("Recovery text should fit at ${size.first}dp width",
                    message.layout.height <= message.height - message.paddingTop - message.paddingBottom)
            }
        }
    }

    @Test fun signedOutAndEmptyStatesOfferRecovery() {
        FlixieWidgetStore.sync(context, payload(null, 0))
        instrumentation.runOnMainSync {
            val view = FlixieWatchlistWidget().views(context, options(300)).apply(context, FrameLayout(context))
            assertEquals("Sign in to see your saved titles", view.findViewById<TextView>(R.id.widget_message).text.toString())
        }
        FlixieWidgetStore.sync(context, payload(count = 0))
        instrumentation.runOnMainSync {
            val view = FlixieWatchlistWidget().views(context, options(300)).apply(context, FrameLayout(context))
            assertEquals("Save something for later", view.findViewById<TextView>(R.id.widget_message).text.toString())
        }
    }

    @Test fun realPosterReplacesFallbackAndRemovedSaveDisappears() {
        FlixieWidgetStore.sync(context, payload(count = 1))
        val snapshot = FlixieWidgetStore.read(context)
        val item = snapshot.getJSONArray("items").getJSONObject(0)
        val bitmap = Bitmap.createBitmap(40, 60, Bitmap.Config.ARGB_8888)
        try {
            assertTrue(FlixieWidgetStore.publishPoster(context, snapshot.getString("revision"), item.getString("file"), bitmap))
            instrumentation.runOnMainSync {
                val view = FlixieWatchlistWidget().views(context, options(300)).apply(context, FrameLayout(context))
                assertEquals(View.VISIBLE, view.findViewById<ImageView>(R.id.widget_poster_0).visibility)
                assertEquals(View.GONE, view.findViewById<TextView>(R.id.widget_title_0).visibility)
                assertEquals(View.INVISIBLE, view.findViewById<View>(R.id.widget_slot_1).visibility)
            }
            FlixieWidgetStore.sync(context, payload(count = 0))
            assertNull(FlixieWidgetStore.poster(context, item))
        } finally { bitmap.recycle() }
    }

    @Test fun captureNativeWidgetPreviewWhenRequested() {
        if (InstrumentationRegistry.getArguments().getString("captureWidgets") != "true") return
        val posters = listOf("/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg", "/vfrQk5IPloGg1v9Rzbh2Eg3VGyM.jpg",
            "/5rhTDKUhPYvpdQIijFIs5VoWsON.jpg", "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg")
        FlixieWidgetStore.sync(context, mapOf("account" to "fixture-preview", "items" to posters.mapIndexed { i, poster ->
            mapOf("id" to "fixture-$i", "title" to listOf("Interstellar", "Alien", "The Odyssey", "Spirited Away")[i], "poster" to poster)
        }))
        val deadline = System.currentTimeMillis() + 25000
        while (System.currentTimeMillis() < deadline) {
            val items = FlixieWidgetStore.read(context).getJSONArray("items")
            if ((0 until 4).all { FlixieWidgetStore.poster(context, items.getJSONObject(it)) != null }) break
            Thread.sleep(250)
        }
        val intent = Intent(context, WidgetPreviewActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val activity = instrumentation.startActivitySync(intent)
        instrumentation.waitForIdleSync()
        val drawn = java.util.concurrent.CountDownLatch(1)
        var screenshot: Bitmap? = null
        instrumentation.runOnMainSync {
            val decor = activity.window.decorView
            decor.postDelayed({
                screenshot = Bitmap.createBitmap(decor.width, decor.height, Bitmap.Config.ARGB_8888)
                android.view.PixelCopy.request(activity.window, screenshot!!, { result ->
                    assertEquals(android.view.PixelCopy.SUCCESS, result)
                    drawn.countDown()
                }, android.os.Handler(android.os.Looper.getMainLooper()))
            }, 1500)
        }
        assertTrue("Native preview should draw", drawn.await(10, java.util.concurrent.TimeUnit.SECONDS))
        assertNotNull(screenshot)
        val output = java.io.File(context.getExternalFilesDir(null), "android-widgets.png")
        output.outputStream().use { screenshot!!.compress(Bitmap.CompressFormat.PNG, 100, it) }
        instrumentation.runOnMainSync { activity.finish() }
    }

    @Test fun providersAreRegisteredWithResizableHomeScreenMetadata() {
        val providers = AppWidgetManager.getInstance(context).installedProviders.filter { it.provider.packageName == context.packageName }
        assertTrue(providers.any { it.provider.className == FlixieSearchWidget::class.java.name })
        val watchlist = providers.single { it.provider.className == FlixieWatchlistWidget::class.java.name }
        assertEquals(android.appwidget.AppWidgetProviderInfo.RESIZE_HORIZONTAL or android.appwidget.AppWidgetProviderInfo.RESIZE_VERTICAL, watchlist.resizeMode)
    }

    @Test fun widgetTapsLaunchTheCorrectDeepLink() {
        for (watchlist in listOf(false, true)) {
            val monitor = instrumentation.addMonitor(MainActivity::class.java.name, null, false)
            instrumentation.runOnMainSync {
                val views = if (watchlist) FlixieWatchlistWidget().views(context, options(300))
                    else FlixieSearchWidget().views(context)
                val root = views.apply(context, FrameLayout(context))
                assertTrue("Actual widget root must handle a tap", root.findViewById<View>(R.id.widget_root).performClick())
            }
            val activity = instrumentation.waitForMonitorWithTimeout(monitor, 15000)
            instrumentation.removeMonitor(monitor)
            assertNotNull("Widget tap should launch Flixie", activity)
            assertEquals(Intent.ACTION_VIEW, activity!!.intent.action)
            assertEquals(if (watchlist) "flixie:///watchlist" else "flixie:///search?focus=1", activity.intent.data.toString())
            instrumentation.runOnMainSync { activity.finish() }
            instrumentation.waitForIdleSync()
        }
    }
}
