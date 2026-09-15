package com.example.antivirus_mobile

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.FileObserver
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.OutputStreamWriter
import java.io.PrintWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

import android.content.ContentUris
import android.provider.MediaStore
import org.json.JSONArray
import org.json.JSONObject

class RealtimeGuardForegroundService : Service() {

    companion object {
        val restoredFilesWhitelist = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()

        fun addRestoredFile(filePath: String, fileName: String) {
            restoredFilesWhitelist.add(filePath.lowercase())
            restoredFilesWhitelist.add(fileName.lowercase())
        }

        fun isRestoredFile(file: File): Boolean {
            val pathMatch = restoredFilesWhitelist.contains(file.absolutePath.lowercase())
            val nameMatch = restoredFilesWhitelist.contains(file.name.lowercase())
            return pathMatch || nameMatch
        }
    }

    private val fileObservers = mutableListOf<FileObserver>()
    private val CHANNEL_ID = "mangodefend_realtime_guard"
    private val NOTIFICATION_ID = 9901
    private val THREAT_CHANNEL_ID = "mangodefend_threat_alert"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        startForegroundServiceNotification()
        startDownloadFileObserver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundServiceNotification()
        if (fileObservers.isEmpty()) {
            startDownloadFileObserver()
        }
        return START_STICKY
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager?

            // 1. Channel Foreground Service Persisten
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Mangodefend Real-Time Guard",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Layanan Proteksi Latar Belakang Aktif"
            }
            manager?.createNotificationChannel(serviceChannel)

            // 2. Channel Notifikasi Peringatan Ancaman (Heads-Up)
            val threatChannel = NotificationChannel(
                THREAT_CHANNEL_ID,
                "Peringatan Ancaman Real-Time",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi Peringatan Saat Malware Ditemukan di Background"
                enableVibration(true)
            }
            manager?.createNotificationChannel(threatChannel)
        }
    }

    private fun startForegroundServiceNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingIntentFlags)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Mangodefend Real-Time Guard")
            .setContentText("Pemantauan folder Download & latar belakang aktif")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun registerObserverForDir(dir: File, currentDepth: Int = 0) {
        if (!dir.exists() || !dir.isDirectory || currentDepth > 2) return

        val eventMask = FileObserver.CLOSE_WRITE or FileObserver.CREATE or FileObserver.MOVED_TO or FileObserver.MODIFY

        try {
            val observer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                object : FileObserver(dir, eventMask) {
                    override fun onEvent(event: Int, path: String?) {
                        if (path != null) {
                            val targetFile = File(dir, path)
                            if (targetFile.isDirectory && (event == FileObserver.CREATE || event == FileObserver.MOVED_TO)) {
                                registerObserverForDir(targetFile, currentDepth + 1)
                            } else if (!targetFile.isDirectory) {
                                Log.i("RealtimeGuardService", "🔔 TERDETEKSI EVENT FILE DI FOLDER ${dir.name}: $path (Event Code: $event)")
                                handleFileEvent(targetFile)
                            }
                        }
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                object : FileObserver(dir.absolutePath, eventMask) {
                    override fun onEvent(event: Int, path: String?) {
                        if (path != null) {
                            val targetFile = File(dir.absolutePath, path)
                            if (targetFile.isDirectory && (event == FileObserver.CREATE || event == FileObserver.MOVED_TO)) {
                                registerObserverForDir(targetFile, currentDepth + 1)
                            } else if (!targetFile.isDirectory) {
                                Log.i("RealtimeGuardService", "🔔 TERDETEKSI EVENT FILE DI FOLDER ${dir.name}: $path (Event Code: $event)")
                                handleFileEvent(targetFile)
                            }
                        }
                    }
                }
            }
            observer.startWatching()
            fileObservers.add(observer)
            Log.i("RealtimeGuardService", "🟢 Real-Time Guard FileObserver MENGAWASI FOLDER: ${dir.absolutePath}")
        } catch (e: Exception) {
            Log.w("RealtimeGuardService", "Gagal mendaftarkan FileObserver pada ${dir.absolutePath}: ${e.message}")
        }

        // Daftarkan juga seluruh sub-folder yang ada saat ini
        try {
            dir.listFiles()?.forEach { sub ->
                if (sub.isDirectory && !sub.name.startsWith(".")) {
                    registerObserverForDir(sub, currentDepth + 1)
                }
            }
        } catch (_: Exception) {}
    }

    private fun startDownloadFileObserver() {
        fileObservers.forEach { it.stopWatching() }
        fileObservers.clear()

        val targetPaths = listOf(
            "/storage/emulated/0/Download",
            "/storage/emulated/0/Documents",
            "/storage/emulated/0/Download/Bluetooth",
            "/storage/emulated/0/Pictures",
            "/storage/emulated/0/Download/Telegram",
            "/storage/emulated/0/Pictures/Telegram",
            "/storage/emulated/0/Pictures/WhatsApp",
            "/storage/emulated/0/Movies/WhatsApp",
            "/storage/emulated/0/Movies/Telegram",
            "/storage/emulated/0/WhatsApp/Media",
            "/storage/emulated/0/Android/media/org.telegram.messenger",
            "/storage/emulated/0/Android/data/org.telegram.messenger/files/Telegram"
        )

        for (pathStr in targetPaths) {
            val dir = File(pathStr)
            if (!dir.exists()) {
                try { dir.mkdirs() } catch (_: Exception) {}
            }
            if (dir.exists()) {
                registerObserverForDir(dir, 0)
            }
        }
    }

    private val highRiskExtensions = setOf(
        "apk", "dex", "sh", "exe", "bat", "vbs", "js", "jar", "py", "elf", "so", "php"
    )

    private val fakeMediaExtensions = setOf(
        "jpg", "jpeg", "png", "pdf", "docx", "xlsx", "txt", "mp4", "webp"
    )

    private val suspiciousKeywords = setOf(
        "malware", "trojan", "spyware", "keylogger", "stealer", "ransomware",
        "backdoor", "payload", "exploit", "rat", "hacktool", "mod_vips", "cheat_engine"
    )

    private fun getBytesFromMediaStoreRecent(file: File): ByteArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        try {
            val urisToTry = arrayOf(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                MediaStore.Files.getContentUri("external")
            )

            for (queryUri in urisToTry) {
                val projection = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME)
                val sortOrder = "${MediaStore.MediaColumns.DATE_ADDED} DESC"

                contentResolver.query(queryUri, projection, null, null, sortOrder)?.use { cursor ->
                    val idIdx = cursor.getColumnIndex(MediaStore.MediaColumns._ID)
                    val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)

                    var count = 0
                    while (cursor.moveToNext() && count < 15) {
                        count++
                        val name = if (nameIdx != -1) cursor.getString(nameIdx) ?: "" else ""
                        if (name.equals(file.name, ignoreCase = true) || (name.isNotEmpty() && file.name.contains(name, ignoreCase = true))) {
                            val id = cursor.getLong(idIdx)
                            val contentUri = ContentUris.withAppendedId(queryUri, id)
                            contentResolver.openInputStream(contentUri)?.use { stream ->
                                val bytes = stream.readBytes()
                                if (bytes.isNotEmpty()) {
                                    Log.i("RealtimeGuardService", "✅ Berhasil membaca ${file.name} via MediaStore Recent Query ($queryUri, ${bytes.size} bytes)")
                                    return bytes
                                }
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w("RealtimeGuardService", "getBytesFromMediaStoreRecent throw: ${e.message}")
        }
        return null
    }

    /// Robust File Reader (Membaca file sekali ke ByteArray untuk menghindari Lock & EACCES I/O Stream)
    private fun readBytesSafely(file: File): ByteArray? {
        if (!file.exists() || file.name.startsWith(".")) return null

        for (attempt in 1..6) {
            // Attempt 1: Direct RandomAccessFile (Bisa membaca file yang sedang di-write oleh Chrome tanpa terhalang Lock)
            try {
                if (file.exists() && file.length() > 0L) {
                    val raf = java.io.RandomAccessFile(file, "r")
                    val bytes = ByteArray(raf.length().toInt())
                    raf.readFully(bytes)
                    raf.close()
                    if (bytes.isNotEmpty()) {
                        Log.i("RealtimeGuardService", "✅ Berhasil membaca ${file.name} via RandomAccessFile (${bytes.size} bytes)")
                        return bytes
                    }
                }
            } catch (e: Exception) {
                Log.w("RealtimeGuardService", "Attempt 1 (RAF) $attempt untuk ${file.name}: ${e.message}")
            }

            // Attempt 2: Direct File readBytes jika diizinkan OS
            try {
                if (file.exists() && file.length() > 0L) {
                    val bytes = file.readBytes()
                    if (bytes.isNotEmpty()) {
                        Log.i("RealtimeGuardService", "✅ Berhasil membaca ${file.name} via direct readBytes (${bytes.size} bytes)")
                        return bytes
                    }
                }
            } catch (e: Exception) {
                Log.w("RealtimeGuardService", "Attempt 2 (readBytes) $attempt untuk ${file.name}: ${e.message}")
            }

            // Attempt 3: Buka via ContentResolver MediaStore (Downloads, Images, Files URIs - DISPLAY_NAME filter)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val urisToTry = arrayOf(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    MediaStore.Files.getContentUri("external")
                )

                for (queryUri in urisToTry) {
                    try {
                        val projection = arrayOf(MediaStore.MediaColumns._ID)
                        val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                        val selectionArgs = arrayOf(file.name)

                        contentResolver.query(queryUri, projection, selection, selectionArgs, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                                val contentUri = ContentUris.withAppendedId(queryUri, id)
                                contentResolver.openInputStream(contentUri)?.use { stream ->
                                    val bytes = stream.readBytes()
                                    if (bytes.isNotEmpty()) {
                                        Log.i("RealtimeGuardService", "✅ Berhasil membaca ${file.name} via ContentResolver MediaStore (${bytes.size} bytes)")
                                        return bytes
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.w("RealtimeGuardService", "Attempt 3 (MediaStore) $attempt $queryUri untuk ${file.name}: ${e.message}")
                    }
                }
            }

            // Attempt 4: MediaStore Recent Query (Menemukan file terunduh terbaru)
            val recentBytes = getBytesFromMediaStoreRecent(file)
            if (recentBytes != null && recentBytes.isNotEmpty()) {
                return recentBytes
            }

            try { Thread.sleep(600) } catch (_: Exception) {}
        }

        Log.w("RealtimeGuardService", "❌ Seluruh 6 percobaan membaca file ${file.name} gagal.")
        return null
    }

    private fun handleFileEvent(file: File) {
        if (!file.exists() || file.isDirectory || file.name.startsWith(".") || file.name.endsWith(".tmp") || file.name.endsWith(".crdownload") || file.name.endsWith(".vir")) {
            return
        }

        // Beri jeda 1200ms agar browser melepaskan penulisan akhir & file lock
        Thread.sleep(1200)
        if (!file.exists() || file.length() == 0L) return

        if (isRestoredFile(file)) {
            Log.i("RealtimeGuardService", "🛡️ File ${file.name} dilewati dari Real-Time Guard karena merupakan file yang dipulihkan pengguna dari Karantina.")
            return
        }

        Log.i("RealtimeGuardService", "🔍 Real-Time Guard mengevaluasi file terunduh: ${file.name} (Ukuran: ${file.length()} bytes)")

        val fileBytes = readBytesSafely(file)
        if (fileBytes == null || fileBytes.isEmpty()) {
            Log.w("RealtimeGuardService", "⚠️ Gagal membaca data biner file ${file.name} (File terkunci/Izin OS tertahan).")
            return
        }

        try {
            val fileName = file.name.lowercase()
            var isThreatDetected = false
            var threatReason = "Ancaman Malware Real-Time"

            // 1. Cek String EICAR Standard Test File
            val content = String(fileBytes, Charsets.UTF_8)
            if (content.contains("EICAR-STANDARD-ANTIVIRUS-TEST-FILE")) {
                isThreatDetected = true
                threatReason = "EICAR Test Signature"
                Log.w("RealtimeGuardService", "🚨 ANCAMAN REAL-TIME TERDETEKSI: String EICAR ditemukan pada ${file.name}!")
            }

            // 2. Cek Signature SHA-256 via MDB1 Binary Search O(log N) di signatures.bin
            if (!isThreatDetected) {
                if (isKnownMaliciousHashBytes(fileBytes)) {
                    isThreatDetected = true
                    threatReason = "MDB1 Database Signature"
                    Log.w("RealtimeGuardService", "🚨 ANCAMAN REAL-TIME TERDETEKSI: Hash SHA-256 cocok dengan Database Signature MDB1 pada ${file.name}!")
                }
            }

            // 3. Deteksi Heuristik: Double Extension Spoofing (Contoh: surat.pdf.apk, foto.jpg.exe)
            if (!isThreatDetected) {
                val parts = fileName.split(".")
                if (parts.size > 2) {
                    val lastExt = parts.last()
                    val secondLastExt = parts[parts.size - 2]
                    if (highRiskExtensions.contains(lastExt) && fakeMediaExtensions.contains(secondLastExt)) {
                        isThreatDetected = true
                        threatReason = "Double Extension Spoofing"
                        Log.w("RealtimeGuardService", "🚨 ANCAMAN REAL-TIME TERDETEKSI: Pemalsuan Ekstensi Ganda (Double Extension Spoofing) pada ${file.name}!")
                    }
                }
            }

            // 4. Deteksi Heuristik: Kata Kunci Indikator Malware pada Nama File
            if (!isThreatDetected) {
                for (keyword in suspiciousKeywords) {
                    if (fileName.contains(keyword)) {
                        isThreatDetected = true
                        threatReason = "Kata Kunci Indikator Malware ($keyword)"
                        Log.w("RealtimeGuardService", "🚨 ANCAMAN REAL-TIME TERDETEKSI: Kata Kunci Indikator Malware '$keyword' pada ${file.name}!")
                        break
                    }
                }
            }

            // 5. Deteksi Heuristik: Header Magic Bytes (Pemalsuan File ZIP/APK sebagai Gambar/Dokumen)
            if (!isThreatDetected && fileBytes.size > 4) {
                val isZipOrApk = fileBytes[0] == 0x50.toByte() && fileBytes[1] == 0x4B.toByte() &&
                                 fileBytes[2] == 0x03.toByte() && fileBytes[3] == 0x04.toByte()
                val isImageExt = fileName.endsWith(".jpg") || fileName.endsWith(".jpeg") ||
                                 fileName.endsWith(".png") || fileName.endsWith(".pdf") ||
                                 fileName.endsWith(".webp")
                if (isZipOrApk && isImageExt) {
                    isThreatDetected = true
                    threatReason = "Pemalsuan Header Magic Bytes"
                    Log.w("RealtimeGuardService", "🚨 ANCAMAN REAL-TIME TERDETEKSI: Pemalsuan Header Magic Bytes ZIP/APK pada ${file.name}!")
                }
            }

            // Eksekusi Karantina Otomatis & Kirim Notifikasi jika Terbukti Berbahaya
            if (isThreatDetected) {
                Log.w("RealtimeGuardService", "🛑 ANCAMAN REAL-TIME TERDETEKSI di Database/Heuristik Lokal HP: ${file.name}! Mengisolasi ke Karantina (Scanning Cloud ML dilewati).")
                quarantineFileBackground(file, threatReason, fileBytes)
            } else {
                Log.i("RealtimeGuardService", "✅ File ${file.name} AMAN di Database/Heuristik Lokal HP. Melanjutkan scanning lanjutan ke Cloud Machine Learning...")
                analyzeFileWithCloudML(file, fileBytes)
            }
        } catch (e: Exception) {
            Log.e("RealtimeGuardService", "Error evaluasi file real-time: $e")
        }
    }

    /// Mengirim file terunduh ke FastAPI Python Cloud ML Server (http://192.168.100.22:8000/api/v1/scans/analyze)
    private fun analyzeFileWithCloudML(file: File, fileBytes: ByteArray) {
        Thread {
            try {
                Log.i("RealtimeGuardService", "🌐 [REALTIME CLOUD ML] Mengirim file ${file.name} (${fileBytes.size} bytes) ke Cloud ML API (http://192.168.100.22:8000/api/v1/scans/analyze)...")

                val boundary = "---Boundary${System.currentTimeMillis()}"
                val url = URL("http://192.168.100.22:8000/api/v1/scans/analyze")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.connectTimeout = 5000
                connection.readTimeout = 15000
                connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")

                val outputStream = connection.outputStream
                val writer = PrintWriter(OutputStreamWriter(outputStream, "UTF-8"), true)

                // Standard field: scan_type = realtime
                writer.append("--$boundary\r\n")
                writer.append("Content-Disposition: form-data; name=\"scan_type\"\r\n\r\n")
                writer.append("realtime\r\n")
                writer.flush()

                // File multipart
                writer.append("--$boundary\r\n")
                writer.append("Content-Disposition: form-data; name=\"file\"; filename=\"${file.name}\"\r\n")
                writer.append("Content-Type: application/octet-stream\r\n\r\n")
                writer.flush()

                outputStream.write(fileBytes)
                outputStream.flush()

                writer.append("\r\n--$boundary--\r\n")
                writer.flush()
                writer.close()

                val responseCode = connection.responseCode
                if (responseCode in 200..299) {
                    val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                    Log.i("RealtimeGuardService", "🌐 [REALTIME CLOUD ML HASIL]: $responseText")
                    val isCloudMalicious = responseText.lowercase().contains("malicious")
                    if (isCloudMalicious) {
                        Log.w("RealtimeGuardService", "🚨 CLOUD MACHINE LEARNING MEMVONIS ANCAMAN MALWARE PADA ${file.name}! Mengisolasi ke Karantina...")
                        quarantineFileBackground(file, "Cloud Machine Learning", fileBytes)
                    } else {
                        Log.i("RealtimeGuardService", "✅ CLOUD MACHINE LEARNING MEMVONIS FILE ${file.name} AMAN. Menampilkan notifikasi sukses.")
                        saveRealtimeLogToDisk(file, isThreat = false, threatType = "File Terunduh Bersih")
                        showCleanFileNotification(file.name)
                    }
                } else {
                    Log.w("RealtimeGuardService", "🌐 Cloud ML Server merespon HTTP Status $responseCode")
                    saveRealtimeLogToDisk(file, isThreat = false, threatType = "File Terunduh Bersih")
                    showCleanFileNotification(file.name)
                }
            } catch (e: Exception) {
                Log.i("RealtimeGuardService", "🌐 Cloud ML API tidak terjangkau / offline: ${e.message}")
                saveRealtimeLogToDisk(file, isThreat = false, threatType = "File Terunduh Bersih")
                showCleanFileNotification(file.name)
            }
        }.start()
    }

    private var binaryBuffer: ByteArray? = null
    private var entryCount: Int = 0
    private var headerSize: Int = 20

    private fun loadBinarySignatures() {
        if (binaryBuffer != null) return
        try {
            // Priority 1: Baca file update biner terbaru hasil sync Cloud Server dari app_flutter / filesDir
            val flutterDocDirFile = File(filesDir.parentFile, "app_flutter/signatures_updated.bin")
            val updatedFile = File(filesDir, "signatures_updated.bin")
            var bytes: ByteArray? = null
            if (flutterDocDirFile.exists() && flutterDocDirFile.length() >= 8) {
                bytes = flutterDocDirFile.readBytes()
            } else if (updatedFile.exists() && updatedFile.length() >= 8) {
                bytes = updatedFile.readBytes()
            } else {
                // Priority 2: Baca dari asset biner bawaan (assets/signatures.bin)
                applicationContext.assets.open("flutter_assets/assets/signatures.bin").use { stream ->
                    bytes = stream.readBytes()
                }
            }

            if (bytes != null && bytes.size >= 8 &&
                bytes[0] == 0x4D.toByte() && bytes[1] == 0x44.toByte() &&
                bytes[2] == 0x42.toByte() && bytes[3] == 0x31.toByte()) {

                val buffer = ByteBuffer.wrap(bytes)
                buffer.order(ByteOrder.BIG_ENDIAN)

                if (bytes.size >= 20) {
                    val schemaVersion = buffer.getInt(4)
                    entryCount = buffer.getInt(8)
                    val buildTimestamp = buffer.getLong(12)
                    headerSize = 20
                    Log.i("RealtimeGuardService", "Berhasil memuat Database Signature MDB1 (Header 20-byte): $entryCount entry, v$schemaVersion, timestamp: $buildTimestamp")
                } else {
                    entryCount = buffer.getInt(4)
                    headerSize = 8
                    Log.i("RealtimeGuardService", "Berhasil memuat Database Signature MDB1 (Header 8-byte Legacy): $entryCount entry")
                }
                binaryBuffer = bytes
            }
        } catch (e: Exception) {
            Log.e("RealtimeGuardService", "Gagal memuat database signature biner: $e")
        }
    }

    private fun isKnownMaliciousHashBytes(fileBytes: ByteArray): Boolean {
        loadBinarySignatures()
        val buffer = binaryBuffer ?: return false
        if (entryCount == 0) return false

        val digest = MessageDigest.getInstance("SHA-256")
        val sha256Bytes = digest.digest(fileBytes)
        if (sha256Bytes.size != 32) return false

        var low = 0
        var high = entryCount - 1

        while (low <= high) {
            val mid = (low + high) ushr 1
            val offset = headerSize + (mid * 32)
            if (offset + 32 > buffer.size) break

            var cmp = 0
            for (i in 0 until 32) {
                val byteA = sha256Bytes[i].toInt() and 0xFF
                val byteB = buffer[offset + i].toInt() and 0xFF
                if (byteA != byteB) {
                    cmp = byteA - byteB
                    break
                }
            }

            if (cmp == 0) return true
            else if (cmp < 0) high = mid - 1
            else low = mid + 1
        }
        return false
    }

    private fun saveRealtimeLogToDisk(
        file: File,
        isThreat: Boolean,
        threatType: String,
        quarantinedPath: String? = null
    ) {
        try {
            val appFlutterDir = File(filesDir.parentFile, "app_flutter")
            if (!appFlutterDir.exists()) appFlutterDir.mkdirs()

            val logFile = File(appFlutterDir, "activity_logs_store.json")

            val existingArray = if (logFile.exists() && logFile.length() > 0) {
                try {
                    val content = logFile.readText()
                    if (content.trim().isNotEmpty()) {
                        JSONArray(content)
                    } else {
                        JSONArray()
                    }
                } catch (_: Exception) {
                    JSONArray()
                }
            } else {
                JSONArray()
            }

            val sizeKb = if (file.exists() && file.length() > 0) {
                String.format("%.1f KB", file.length() / 1024.0)
            } else {
                "15 KB"
            }

            val fileDetailJson = JSONObject().apply {
                put("fileName", file.name)
                put("filePath", file.absolutePath)
                put("quarantinedPath", quarantinedPath ?: "")
                put("threatType", threatType)
                put("fileSize", sizeKb)
                put("isSafe", !isThreat)
                put("isFalsePositive", false)
            }

            val filesArray = JSONArray().apply {
                put(fileDetailJson)
            }

            val logItemJson = JSONObject().apply {
                put("id", "realtime_${System.currentTimeMillis()}")
                put("title", "Real-Time Guard Protection")
                put("subtitle", if (isThreat) "1 file dipindai • 1 ancaman terdeteksi" else "1 file dipindai • Bebas ancaman")
                put("time", "Baru Saja")
                put("category", if (isThreat) "Karantina" else "Pemindaian")
                put("badgeText", if (isThreat) "1 Ancaman" else "1 File")
                put("isQuarantined", isThreat)
                put("files", filesArray)
            }

            val newArray = JSONArray()
            newArray.put(logItemJson)

            for (i in 0 until existingArray.length()) {
                newArray.put(existingArray.get(i))
            }

            logFile.writeText(newArray.toString(2))
            Log.i("RealtimeGuardService", "📝 Berhasil mencatat log aktivitas Real-Time Guard untuk ${file.name} (Ancaman: $isThreat, Tipe: $threatType) ke ${logFile.absolutePath}")
        } catch (e: Exception) {
            Log.e("RealtimeGuardService", "Gagal menyimpan log aktivitas real-time ke disk: ${e.message}")
        }
    }

    private fun quarantineFileBackground(
        sourceFile: File,
        threatReason: String = "Ancaman Real-Time Guard",
        cachedBytes: ByteArray? = null
    ) {
        try {
            val vaultDir = File(filesDir, "app_flutter/quarantine_vault")
            if (!vaultDir.exists()) vaultDir.mkdirs()

            val targetFile = File(vaultDir, "${System.currentTimeMillis()}_${sourceFile.name}.vir")

            var copied = false
            if (sourceFile.exists() && sourceFile.length() > 0) {
                try {
                    sourceFile.copyTo(targetFile, overwrite = true)
                    copied = targetFile.exists() && targetFile.length() > 0
                } catch (e: Exception) {
                    Log.w("RealtimeGuardService", "sourceFile.copyTo tertahan: ${e.message}")
                }
            }

            if (!copied && cachedBytes != null && cachedBytes.isNotEmpty()) {
                try {
                    targetFile.writeBytes(cachedBytes)
                    copied = targetFile.exists() && targetFile.length() > 0
                    Log.i("RealtimeGuardService", "🔒 Berhasil mengisolasi ${sourceFile.name} (${cachedBytes.size} bytes) dari RAM ke Vault Karantina.")
                } catch (e: Exception) {
                    Log.w("RealtimeGuardService", "Gagal menulis cachedBytes ke Vault Karantina: ${e.message}")
                }
            }

            if (copied) {
                val fileName = sourceFile.name
                Log.i("RealtimeGuardService", "🔒 Berhasil mengamankan $fileName ke Vault Karantina. Menghapus file asli dari lokasi terunduh...")

                // 1. Percobaan Hapus POSIX
                var deleted = if (sourceFile.exists()) {
                    try { sourceFile.delete() } catch (_: Exception) { false }
                } else true

                // 2. Percobaan Hapus via ContentResolver MediaStore jika POSIX tertahan Scoped Storage
                if (!deleted && sourceFile.exists() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val urisToTry = arrayOf(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        MediaStore.Files.getContentUri("external")
                    )

                    for (queryUri in urisToTry) {
                        try {
                            val projection = arrayOf(MediaStore.MediaColumns._ID)
                            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
                            val selectionArgs = arrayOf(sourceFile.name)

                            contentResolver.query(queryUri, projection, selection, selectionArgs, null)?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                                    val contentUri = ContentUris.withAppendedId(queryUri, id)
                                    val rowsDeleted = contentResolver.delete(contentUri, null, null)
                                    if (rowsDeleted > 0) {
                                        deleted = true
                                        Log.i("RealtimeGuardService", "🗑️ Berhasil menghapus $fileName via ContentResolver MediaStore.")
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.w("RealtimeGuardService", "ContentResolver delete error $queryUri: ${e.message}")
                        }
                        if (deleted) break
                    }
                }

                // 3. Percobaan Truncate / Zero Out jika file tidak bisa di-delete oleh OS
                if (!deleted && sourceFile.exists()) {
                    try {
                        val raf = java.io.RandomAccessFile(sourceFile, "rw")
                        raf.setLength(0L)
                        raf.close()
                        Log.w("RealtimeGuardService", "⚠️ Berhasil mengosongkan (zero out) payload $fileName di Downloads.")
                    } catch (_: Exception) {}
                }

                // 4. Update MediaStore agar File Manager / Galeri memperbarui daftar file
                MediaScannerConnection.scanFile(this, arrayOf(sourceFile.absolutePath), null, null)

                // 5. Catat log aktivitas ke disk
                saveRealtimeLogToDisk(sourceFile, isThreat = true, threatType = threatReason, quarantinedPath = targetFile.absolutePath)

                // 6. Tampilkan Notifikasi Peringatan Ancaman
                showThreatAlertNotification(fileName)
            }
        } catch (e: Exception) {
            Log.e("RealtimeGuardService", "Gagal memindahkan file ke karantina: ${e.message}")
        }
    }

    private fun showThreatAlertNotification(fileName: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, pendingIntentFlags)

        val notification = NotificationCompat.Builder(this, THREAT_CHANNEL_ID)
            .setContentTitle("⚠️ Ancaman Terdeteksi & Diisolasi!")
            .setContentText("Berkas '$fileName' berbahaya di-download & telah dipindahkan ke Karantina.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun showCleanFileNotification(fileName: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, pendingIntentFlags)

        val notification = NotificationCompat.Builder(this, THREAT_CHANNEL_ID)
            .setContentTitle("✅ Berkas Terunduh Aman")
            .setContentText("Berkas '$fileName' telah dipindai & dinyatakan bersih oleh Real-Time Guard.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    override fun onDestroy() {
        Log.i("RealtimeGuardService", "🛑 Real-Time Guard Foreground Service DIMATIKAN oleh Pengguna! Menghentikan ${fileObservers.size} FileObserver folder...")
        fileObservers.forEach { it.stopWatching() }
        fileObservers.clear()
        Log.i("RealtimeGuardService", "✅ Real-Time Guard Service berhasil dimatikan sepenuhnya.")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
