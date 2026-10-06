package com.flixie.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors

/** Private, no-backup snapshot. No credentials are sent to the Home Screen. */
object FlixieWidgetStore {
    private val lock = Any()
    private val downloads = Executors.newSingleThreadExecutor()
    private const val MAX_BYTES = 2 * 1024 * 1024
    private fun directory(context: Context) = File(context.noBackupFilesDir, "flixie_widgets").apply { mkdirs() }

    fun read(context: Context): JSONObject = synchronized(lock) {
        try {
            JSONObject(AtomicFile(File(directory(context), "snapshot.json")).readFully().toString(Charsets.UTF_8))
        } catch (_: Exception) { JSONObject().put("signedIn", false).put("items", JSONArray()) }
    }

    private fun write(context: Context, value: JSONObject) {
        val file = AtomicFile(File(directory(context), "snapshot.json"))
        val output = file.startWrite()
        try {
            output.write(value.toString().toByteArray(Charsets.UTF_8))
            file.finishWrite(output)
        } catch (error: Exception) { file.failWrite(output); throw error }
    }

    fun sync(context: Context, payload: Map<*, *>) {
        val app = context.applicationContext
        val revision = UUID.randomUUID().toString()
        val account = payload["account"] as? String
        val items = JSONArray()
        if (!account.isNullOrBlank()) {
            (payload["items"] as? List<*>)?.take(4)?.forEachIndexed { index, raw ->
                val item = raw as? Map<*, *> ?: return@forEachIndexed
                items.put(JSONObject().put("id", item["id"] as? String ?: "")
                    .put("title", item["title"] as? String ?: "Saved title")
                    .put("poster", item["poster"] as? String ?: JSONObject.NULL)
                    .put("file", "$revision-$index.jpg"))
            }
        }
        synchronized(lock) {
            directory(app).listFiles()?.filter { it.extension == "jpg" }?.forEach { it.delete() }
            write(app, JSONObject().put("revision", revision).put("signedIn", !account.isNullOrBlank()).put("items", items))
            FlixieWatchlistWidget.updateAll(app)
        }
        if (items.length() == 0) return
        downloads.execute {
            for (index in 0 until items.length()) {
                if (read(app).optString("revision") != revision) break
                val item = items.getJSONObject(index)
                val bitmap = downloadPoster(item.optString("poster")) ?: continue
                try {
                    publishPoster(app, revision, item.getString("file"), bitmap)
                } finally { bitmap.recycle() }
            }
        }
    }

    /** A late image must never republish another account's cleared snapshot. */
    internal fun publishPoster(context: Context, revision: String, filename: String, bitmap: Bitmap): Boolean = synchronized(lock) {
        if (read(context).optString("revision") != revision || !filename.matches(Regex("[a-f0-9-]+-[0-3]\\.jpg"))) return false
        try {
            File(directory(context), filename).outputStream().use {
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it)) return false
            }
            FlixieWatchlistWidget.updateAll(context)
            true
        } catch (_: Exception) {
            File(directory(context), filename).delete()
            false
        }
    }

    fun poster(context: Context, item: JSONObject): Bitmap? = synchronized(lock) {
        val name = item.optString("file")
        if (!name.matches(Regex("[a-f0-9-]+-[0-3]\\.jpg"))) return null
        BitmapFactory.decodeFile(File(directory(context), name).path)
    }

    private fun downloadPoster(path: String): Bitmap? {
        if (!path.matches(Regex("/[A-Za-z0-9._-]+"))) return null
        var connection: HttpURLConnection? = null
        return try {
            connection = URL("https://image.tmdb.org/t/p/w185$path").openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.instanceFollowRedirects = false
            if (connection.responseCode != 200 || connection.contentLength > MAX_BYTES) return null
            val bytes = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val size = input.read(buffer)
                    if (size < 0) break
                    if (output.size() + size > MAX_BYTES) return null
                    output.write(buffer, 0, size)
                }
                output.toByteArray()
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0 ||
                bounds.outWidth.toLong() * bounds.outHeight > 1_000_000) return null
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (_: Exception) { null } finally { connection?.disconnect() }
    }
}
