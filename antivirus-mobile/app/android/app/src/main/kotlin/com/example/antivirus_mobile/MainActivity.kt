package com.example.antivirus_mobile

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.antivirus_mobile/quarantine"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getHardwareDeviceId" -> {
                    try {
                        val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
                        val hardwareSpecs = "${Build.BOARD}_${Build.BOOTLOADER}_${Build.BRAND}_${Build.DEVICE}_${Build.HARDWARE}_${Build.MANUFACTURER}_${Build.MODEL}_${Build.PRODUCT}_$androidId"

                        val md = java.security.MessageDigest.getInstance("SHA-256")
                        val digest = md.digest(hardwareSpecs.toByteArray(Charsets.UTF_8))
                        val hexString = digest.joinToString("") { "%02x".format(it) }
                        val shortHash = if (hexString.length >= 32) hexString.substring(0, 32) else hexString
                        result.success("device-hw-android-$shortHash")
                    } catch (e: Exception) {
                        val fallback = Math.abs("${Build.BRAND}_${Build.MODEL}_${Build.BOARD}".hashCode())
                        result.success("device-hw-android-$fallback")
                    }
                }
                "getDeviceModelName" -> {
    try {
        val brand = Build.BRAND.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        val model = Build.MODEL

        // Jika nama model sudah mengandung kata brand di awalnya, jangan gabungkan lagi
        if (model.lowercase().startsWith(brand.lowercase())) {
            result.success(model)
        } else {
            result.success("$brand $model")
        }
    } catch (e: Exception) {
        result.success("${Build.MANUFACTURER} ${Build.MODEL}")
    }
}

                "getDeviceOsVersion" -> {
                    try {
                        result.success("Android ${Build.VERSION.RELEASE}")
                    } catch (e: Exception) {
                        result.success("Android OS")
                    }
                }
                "startRealtimeGuardService" -> {
                    try {
                        val intent = Intent(context, RealtimeGuardForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "stopRealtimeGuardService" -> {
                    try {
                        val intent = Intent(context, RealtimeGuardForegroundService::class.java)
                        context.stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "scanMediaFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        MediaScannerConnection.scanFile(context, arrayOf(filePath), null, null)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "checkManageStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "requestManageStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                                result.success(true)
                            } catch (ex: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "quarantineFilePhysically" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val targetPath = call.argument<String>("targetPath")
                    val originalPath = call.argument<String>("originalPath")

                    if (sourcePath == null || targetPath == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    var sFile = File(sourcePath)
                    if (!sFile.exists() && originalPath != null && File(originalPath).exists()) {
                        sFile = File(originalPath)
                    }

                    val tFile = File(targetPath)
                    if (!sFile.exists() || sFile.length() == 0L) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    var quarantined = false
                    try {
                        tFile.parentFile?.mkdirs()
                        sFile.copyTo(tFile, overwrite = true)
                        if (tFile.exists() && tFile.length() > 0) {
                            deleteFilePhysicallyNative(sFile.absolutePath, sFile.name)
                            if (originalPath != null) {
                                deleteFilePhysicallyNative(originalPath, File(originalPath).name)
                            }
                            quarantined = true
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    result.success(quarantined)
                }
                "restoreFilePhysically" -> {
                    val quarantinedPath = call.argument<String>("quarantinedPath")
                    val fileName = call.argument<String>("fileName")
                    val originalPath = call.argument<String>("originalPath")

                    if (quarantinedPath == null || fileName == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val qFile = File(quarantinedPath)
                    if (!qFile.exists() || qFile.length() == 0L) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val targetName = fileName
                    val targetPath: String = when {
                        originalPath != null && !originalPath.contains("/cache/") && !originalPath.contains("/data/user/") -> originalPath
                        targetName.lowercase().contains("screenshot") -> {
                            when {
                                File("/storage/emulated/0/Pictures/Screenshot").exists() -> "/storage/emulated/0/Pictures/Screenshot/$targetName"
                                File("/storage/emulated/0/Pictures/Screenshots").exists() -> "/storage/emulated/0/Pictures/Screenshots/$targetName"
                                File("/storage/emulated/0/DCIM/Screenshot").exists() -> "/storage/emulated/0/DCIM/Screenshot/$targetName"
                                else -> "/storage/emulated/0/Pictures/Screenshot/$targetName"
                            }
                        }
                        targetName.lowercase().endsWith(".jpg") || targetName.lowercase().endsWith(".jpeg") ||
                        targetName.lowercase().endsWith(".png") || targetName.lowercase().endsWith(".webp") -> "/storage/emulated/0/Pictures/$targetName"
                        else -> "/storage/emulated/0/Download/$targetName"
                    }

                    var restored = false
                    try {
                        val targetFile = File(targetPath)
                        targetFile.parentFile?.mkdirs()

                        // Whitelist file di Real-Time Guard agar tidak ter-scan & ter-karantina lagi saat ditulis ke originalPath
                        RealtimeGuardForegroundService.addRestoredFile(targetFile.absolutePath, targetFile.name)

                        // Salin file beserta seluruh byte ukurannya ke lokasi tujuan
                        qFile.copyTo(targetFile, overwrite = true)

                        if (targetFile.exists() && targetFile.length() > 0) {
                            // Indeks ulang file ke Android MediaStore agar muncul di Galeri/Files
                            MediaScannerConnection.scanFile(context, arrayOf(targetFile.absolutePath), null, null)

                            // Hapus file vault karantina setelah berhasil disalin utuh
                            try { qFile.delete() } catch (e: Exception) {}
                            restored = true
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    result.success(restored)
                }
                "deleteFilePhysically" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")

                    if (filePath == null) {
                        result.error("INVALID_PATH", "FilePath is null", null)
                        return@setMethodCallHandler
                    }

                    val isDeleted = deleteFilePhysicallyNative(filePath, fileName)
                    result.success(isDeleted)
                }
                "resolveRealPath" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    val file = File(filePath)
                    val fileName = file.name

                    if (!filePath.contains("/cache/") && !filePath.contains("/data/user/")) {
                        result.success(filePath)
                        return@setMethodCallHandler
                    }

                    // Query MediaStore ContentResolver secara langsung via DISPLAY_NAME
                    var resolvedPath: String? = null
                    try {
                        val projection = arrayOf(MediaStore.MediaColumns.DATA)
                        val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                        val selectionArgs = arrayOf(fileName)
                        val queryUri = MediaStore.Files.getContentUri("external")
                        val cursor = context.contentResolver.query(queryUri, projection, selection, selectionArgs, null)

                        cursor?.use { c ->
                            val dataIndex = c.getColumnIndex(MediaStore.MediaColumns.DATA)
                            while (c.moveToNext()) {
                                if (dataIndex != -1) {
                                    val candidate = c.getString(dataIndex)
                                    if (candidate != null && File(candidate).exists() && !candidate.contains("/cache/")) {
                                        resolvedPath = candidate
                                        break
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    if (resolvedPath != null) {
                        result.success(resolvedPath)
                        return@setMethodCallHandler
                    }

                    // Fallback: Rekursi root SDCard/Penyimpanan Utama
                    try {
                        val rootDir = Environment.getExternalStorageDirectory()
                        val found = findFileInDirNative(rootDir, fileName)
                        if (found != null && found.exists()) {
                            result.success(found.absolutePath)
                            return@setMethodCallHandler
                        }
                    } catch (_: Exception) {}

                    result.success(filePath)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun findFileInDirNative(dir: File, targetName: String): File? {
        try {
            if (!dir.exists() || !dir.isDirectory) return null
            val files = dir.listFiles() ?: return null
            for (file in files) {
                if (file.isDirectory) {
                    if (file.name.startsWith(".") || file.name == "Android") continue
                    val res = findFileInDirNative(file, targetName)
                    if (res != null) return res
                } else if (file.name == targetName) {
                    return file
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private fun deleteFilePhysicallyNative(filePath: String, fileName: String?): Boolean {
        var success = false
        val targetName = fileName ?: File(filePath).name

        // 1. Truncate (kosongkan byte file) & Hapus File System secara langsung
        val pathsToDelete = mutableListOf(
            filePath,
            "/storage/emulated/0/Download/$targetName",
            "/storage/emulated/0/Download/Quick Share/$targetName",
            "/storage/emulated/0/Pictures/$targetName",
            "/storage/emulated/0/Pictures/Screenshot/$targetName",
            "/storage/emulated/0/Pictures/Screenshots/$targetName",
            "/storage/emulated/0/DCIM/$targetName",
            "/storage/emulated/0/DCIM/Camera/$targetName",
            "/storage/emulated/0/DCIM/Screenshot/$targetName",
            "/storage/emulated/0/Documents/$targetName"
        )

        for (pStr in pathsToDelete) {
            val f = File(pStr)
            if (f.exists()) {
                try {
                    val raf = java.io.RandomAccessFile(f, "rw")
                    raf.setLength(0)
                    raf.close()
                } catch (_: Exception) {}
                try {
                    if (f.delete()) {
                        success = true
                    }
                } catch (_: Exception) {}
                try {
                    MediaScannerConnection.scanFile(context, arrayOf(f.absolutePath), null, null)
                } catch (_: Exception) {}
            }
        }

        // 2. Hapus dari MediaStore (Images, Downloads, Files ContentResolver)
        try {
            val resolver = context.contentResolver
            val baseUris = listOf(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                MediaStore.Files.getContentUri("external")
            )

            for (baseUri in baseUris) {
                val projection = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DATA)
                val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ? OR ${MediaStore.MediaColumns.DATA} = ?"
                val selectionArgs = arrayOf(targetName, filePath)

                val cursor = resolver.query(baseUri, projection, selection, selectionArgs, null)
                cursor?.use { c ->
                    val idIndex = c.getColumnIndex(MediaStore.MediaColumns._ID)
                    val dataIndex = c.getColumnIndex(MediaStore.MediaColumns.DATA)
                    while (c.moveToNext()) {
                        if (idIndex != -1) {
                            val id = c.getLong(idIndex)
                            val itemData = if (dataIndex != -1) c.getString(dataIndex) else null

                            if (itemData != null) {
                                val f = File(itemData)
                                if (f.exists()) {
                                    try {
                                        val raf = java.io.RandomAccessFile(f, "rw")
                                        raf.setLength(0)
                                        raf.close()
                                    } catch (_: Exception) {}
                                    try {
                                        if (f.delete()) success = true
                                    } catch (_: Exception) {}
                                }
                            }

                            try {
                                val itemUri = ContentUris.withAppendedId(baseUri, id)
                                val rows = resolver.delete(itemUri, null, null)
                                if (rows > 0) success = true
                            } catch (_: Exception) {}
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return success
    }
}
