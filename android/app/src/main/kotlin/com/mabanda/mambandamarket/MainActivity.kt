package com.mabanda.mambandamarket

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Host activity, plus the small document picker chat needs.
 *
 * `file_picker` would normally cover this, but it still applies its own Kotlin
 * Gradle Plugin, which this project's AGP 9 / built-in-Kotlin toolchain refuses
 * to compile. Rather than pin the whole build back a major version for one
 * dialog, the handful of lines we actually need live here — no plugin, no KGP.
 * Photos still go through image_picker; this covers PDFs and office documents.
 */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pending != null) {
                    result.error("busy", "A picker is already open", null)
                    return@setMethodCallHandler
                }
                pending = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, MIME_TYPES)
                }
                startActivityForResult(intent, REQUEST_CODE)
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CODE) return

        val result = pending ?: return
        pending = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // cancelled
            return
        }
        try {
            result.success(copyToCache(uri))
        } catch (e: Exception) {
            result.error("copy_failed", e.message, null)
        }
    }

    /**
     * The picker hands back a content:// URI, which isn't a readable file path.
     * Stage a copy in the cache dir so the Dart side can upload it like any
     * other File.
     */
    private fun copyToCache(uri: Uri): Map<String, String> {
        val name = displayName(uri)
        val target = File(cacheDir, "chat-doc-${System.currentTimeMillis()}-$name")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot open $uri" }
            target.outputStream().use { output -> input.copyTo(output) }
        }
        return mapOf("path" to target.absolutePath, "name" to name)
    }

    private fun displayName(uri: Uri): String {
        contentResolver
            .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) return cursor.getString(index)
            }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "document"
    }

    private companion object {
        const val CHANNEL = "mambanda/doc_picker"
        const val REQUEST_CODE = 4711

        /** Mirrors the extensions the API accepts for chat-attachments. */
        val MIME_TYPES = arrayOf(
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "text/plain",
        )
    }
}
