// SPDX-License-Identifier: GPL-3.0-or-later
package com.lanna.lanna

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val pickTreeRequest = 4711
    private var pendingPick: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lanna/saf")
            .setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickTree" -> pickTree(result)
            "listTree" -> background(result) { listTree(Uri.parse(call.arguments as String)) }
            "openFd" -> background(result) {
                contentResolver.openFileDescriptor(Uri.parse(call.arguments as String), "r")!!
                    .detachFd()
            }
            "closeFd" -> background(result) {
                ParcelFileDescriptor.adoptFd(call.arguments as Int).close()
                null
            }
            "releaseTree" -> background(result) {
                contentResolver.releasePersistableUriPermission(
                    Uri.parse(call.arguments as String),
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
                null
            }
            "persistedTrees" -> result.success(
                contentResolver.persistedUriPermissions.map { it.uri.toString() },
            )
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("saf", e.message, null) }
            }
        }
    }

    private fun pickTree(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("saf", "Ya hay un selector abierto", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        startActivityForResult(intent, pickTreeRequest)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickTreeRequest) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        result.success(mapOf("uri" to uri.toString(), "name" to treeName(uri)))
    }

    private fun treeName(tree: Uri): String {
        val document = DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        contentResolver.query(
            document,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst()) c.getString(0)?.let { return it } }
        return DocumentsContract.getTreeDocumentId(tree).substringAfterLast(':')
    }

    private fun listTree(tree: Uri): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val pending = ArrayDeque<Pair<String, String>>()
        pending.add(DocumentsContract.getTreeDocumentId(tree) to "")
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        while (pending.isNotEmpty()) {
            val (parent, prefix) = pending.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
            contentResolver.query(children, columns, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0)
                    val name = c.getString(1) ?: continue
                    val path = if (prefix.isEmpty()) name else "$prefix/$name"
                    if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        pending.add(id to path)
                        continue
                    }
                    out.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                            "path" to path,
                            "size" to if (c.isNull(3)) null else c.getLong(3),
                            "modified" to if (c.isNull(4)) null else c.getLong(4),
                        ),
                    )
                }
            }
        }
        return out
    }
}
