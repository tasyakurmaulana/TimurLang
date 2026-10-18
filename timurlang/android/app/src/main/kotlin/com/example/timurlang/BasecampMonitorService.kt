package com.example.timurlang

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class BasecampMonitorService : Service() {

    private var isRunning = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var currentGunungId: String = ""
    private var currentBasecampId: String = ""
    private var basecampName: String = "Basecamp"
    private var mountainName: String = "Gunung"
    private var supabaseUrl: String = ""
    private var supabaseKey: String = ""
    private val alertedSosIds = HashSet<String>()

    companion object {
        private const val TAG = "BasecampMonitorService"
        private const val CHANNEL_RADAR_ID = "basecamp_radar_channel"
        private const val CHANNEL_SOS_ID = "sos_channel"
        private const val NOTIF_RADAR_ID = 998
        private const val NOTIF_SOS_ID = 1
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            currentGunungId = intent.getStringExtra("gunungId") ?: ""
            currentBasecampId = intent.getStringExtra("basecampId") ?: ""
            basecampName = intent.getStringExtra("basecampName") ?: "Basecamp"
            mountainName = intent.getStringExtra("mountainName") ?: "Gunung"
            supabaseUrl = intent.getStringExtra("supabaseUrl") ?: ""
            supabaseKey = intent.getStringExtra("supabaseKey") ?: ""
        }

        startForegroundNotification()

        if (!isRunning) {
            isRunning = true
            acquireWakeLock()
            startBackgroundMonitoringLoop()
        }

        return START_STICKY
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Channel 1: Radar Basecamp (Low importance, ongoing status)
            val radarChannel = NotificationChannel(
                CHANNEL_RADAR_ID,
                "Radar Siaga Basecamp",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Status pemantauan sinyal darurat pendaki di latar belakang"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(radarChannel)

            // Channel 2: SOS Darurat (MAX importance, sound, vibration, popup)
            val alarmSound: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            val sosChannel = NotificationChannel(
                CHANNEL_SOS_ID,
                "SOS Darurat",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Peringatan darurat sinyal SOS dari pendaki"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 200, 600, 200, 1000)
                setSound(alarmSound, audioAttributes)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(sosChannel)
        }
    }

    private fun startForegroundNotification() {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_RADAR_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("📡 Radar Basecamp Siaga 24/7 ($mountainName)")
            .setContentText("$basecampName aktif memantau sinyal SOS pendaki di latar belakang.")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIF_RADAR_ID, notification)
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "timurlang:BasecampMonitorWakeLock"
            ).apply {
                acquire()
            }
            Log.d(TAG, "WakeLock acquired for background monitoring.")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring WakeLock: ${e.message}")
        }
    }

    private fun startBackgroundMonitoringLoop() {
        thread(isDaemon = true, name = "BasecampSOSWatcher") {
            Log.d(TAG, "Background SOS polling thread started for gunung: $currentGunungId")
            while (isRunning) {
                if (supabaseUrl.isNotEmpty() && supabaseKey.isNotEmpty()) {
                    try {
                        checkSupabaseSOS()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error polling Supabase: ${e.message}")
                    }
                }

                try {
                    Thread.sleep(3000) // Poll setiap 3 detik
                } catch (e: InterruptedException) {
                    break
                }
            }
            Log.d(TAG, "Background SOS polling thread stopped.")
        }
    }

    private fun checkSupabaseSOS() {
        val endpoint = "$supabaseUrl/rest/v1/sos_incident_logs?status_penanganan=eq.darurat_aktif&order=waktu_kejadian.desc"
        val url = URL(endpoint)
        val conn = url.openConnection() as HttpURLConnection

        conn.requestMethod = "GET"
        conn.setRequestProperty("apikey", supabaseKey)
        conn.setRequestProperty("Authorization", "Bearer $supabaseKey")
        conn.setRequestProperty("Accept", "application/json")
        conn.connectTimeout = 6000
        conn.readTimeout = 6000

        val responseCode = conn.responseCode
        if (responseCode == 200) {
            val reader = BufferedReader(InputStreamReader(conn.inputStream))
            val response = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                response.append(line)
            }
            reader.close()

            val jsonArray = JSONArray(response.toString())
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(i)
                val id = item.optString("id")
                val targetGunung = item.optString("gunung_id")
                val targetBasecamp = item.optString("basecamp_id")
                val namaPendaki = item.optString("nama_pendaki", "Pendaki")
                val lat = item.optDouble("koordinat_lat", -8.108)
                val lon = item.optDouble("koordinat_long", 112.922)

                // Verifikasi apakah insiden ini untuk gunung basecamp ini atau SOS umum
                val isMountainMatch = targetGunung.isEmpty() || targetGunung == "null" || targetGunung == currentGunungId
                val isBasecampMatch = currentBasecampId.isEmpty() || targetBasecamp.isEmpty() || targetBasecamp == "null" || targetBasecamp == currentBasecampId

                if (isMountainMatch && isBasecampMatch) {
                    if (!alertedSosIds.contains(id)) {
                        alertedSosIds.add(id)
                        Log.w(TAG, "🚨 NEW SOS DETECTED NATIVELY: $namaPendaki ($lat, $lon)")
                        triggerEmergencyAlert(id, namaPendaki, lat, lon)
                    }
                }
            }
        }
        conn.disconnect()
    }

    private fun triggerEmergencyAlert(id: String, namaPendaki: String, lat: Double, lon: Double) {
        // 1. Nyalakan dan bangunkan layar HP yang sedang mati / terkunci
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val screenLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "timurlang:SOS_BRIGHT_WAKEUP"
            )
            screenLock.acquire(15000) // Nyalakan layar selama 15 detik
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring screen wake lock: ${e.message}")
        }

        // 2. Mainkan getaran pola darurat
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 600, 200, 600, 200, 1000), -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 600, 200, 600, 200, 1000), -1)
            }
        } catch (_: Exception) {}

        // 3. Mainkan suara alarm sistem
        try {
            val alarmSound: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, alarmSound)
            ringtone?.play()
        } catch (_: Exception) {}

        // 4. Intent untuk membuka dashboard basecamp
        val openIntent = Intent(applicationContext, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra("route", "/basecamp")
        }

        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            id.hashCode(),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val formattedLat = String.format("%.4f", lat)
        val formattedLon = String.format("%.4f", lon)

        val sosNotification = NotificationCompat.Builder(applicationContext, CHANNEL_SOS_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🚨 DARURAT PENDAKI: $namaPendaki!")
            .setContentText("Sinyal SOS di koordinat ($formattedLat, $formattedLon) $mountainName! Buka untuk tindakan SAR.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Pendaki $namaPendaki membunyikan sinyal darurat SOS di koordinat ($formattedLat, $formattedLon)! Segera buka pemantauan Basecamp untuk evakuasi tim SAR.")
            )
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        notificationManager.notify(NOTIF_SOS_ID, sosNotification)

        // 5. Bawa aplikasi langsung ke layar utama di atas lock screen
        try {
            startActivity(openIntent)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        isRunning = false
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (_: Exception) {}
        stopForeground(true)
        super.onDestroy()
        Log.d(TAG, "BasecampMonitorService destroyed.")
    }
}
