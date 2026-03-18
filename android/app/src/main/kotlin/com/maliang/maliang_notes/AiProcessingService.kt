package com.maliang.maliang_notes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class AiProcessingService : Service() {

    companion object {
        private const val TAG = "AiProcessingService"
        const val NOTIFICATION_ID = 99999
        private const val CHANNEL_ID = "memory_live_update"

        private var pendingImagePath: String? = null

        fun start(context: Context) {
            val intent = Intent(context, AiProcessingService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun startWithImage(context: Context, imagePath: String) {
            pendingImagePath = imagePath
            start(context)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AiProcessingService::class.java))
        }
    }

    private val timeoutHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createChannel()
        Log.d(TAG, "前台服务创建")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "前台服务启动命令")
        startForeground(NOTIFICATION_ID, buildNotification())

        val path = pendingImagePath
        if (path != null) {
            pendingImagePath = null
            deliverImageToFlutter(path)
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        timeoutHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
        Log.d(TAG, "前台服务销毁")
    }

    private fun deliverImageToFlutter(imagePath: String) {
        if (MainActivity.isEngineActive && MainActivity.methodChannelInstance != null) {
            Log.d(TAG, "主引擎活跃，直接发送图片")
            Handler(Looper.getMainLooper()).post {
                MainActivity.methodChannelInstance?.invokeMethod(
                    "onTileImage",
                    mapOf("path" to imagePath)
                )
            }
        } else {
            Log.d(TAG, "主引擎不活跃，后台启动 MainActivity")
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
                putExtra("tile_image_path", imagePath)
                putExtra("from_tile_background", true)
            }
            startActivity(launchIntent)
        }

        timeoutHandler.postDelayed({
            Log.w(TAG, "处理超时，强制停止服务")
            stopSelf()
        }, 90_000)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "待办事项",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "显示待处理的记忆事项"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_ai)
            .setContentTitle("AI 识别中")
            .setContentText("正在分析图片内容…")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setProgress(0, 0, true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setRequestPromotedOngoing(true)
        }

        return builder.build()
    }
}
