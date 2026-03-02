package com.maliang.maliang_notes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.maliang.maliang_notes/notification"
    private val NOTIFICATION_CHANNEL_ID = "memory_live_update"
    private val NOTIFICATION_GROUP_KEY = "com.maliang.maliang_notes.pending_group"
    private val ACTION_COMPLETE = "com.maliang.maliang_notes.ACTION_COMPLETE"
    
    private var methodChannel: MethodChannel? = null
    private var initialMemoryIdHash: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkNotificationIntent(intent)
    }

    private fun checkNotificationIntent(intent: Intent?) {
        intent?.let {
            val memoryIdHash = it.getIntExtra("memory_id_hash", -1)
            if (memoryIdHash != -1) {
                initialMemoryIdHash = memoryIdHash
                methodChannel?.invokeMethod("onOpenDetail", mapOf("id" to memoryIdHash))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        createNotificationChannel()
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "收到方法调用: ${call.method}")
            when (call.method) {
                "showLiveUpdateNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val category = call.argument<String>("category") ?: ""
                    Log.d("MainActivity", "显示通知: id=$id, title=$title, category=$category")
                    showLiveUpdateNotification(id, title, category)
                    result.success(null)
                }
                "cancelNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelNotification(id)
                    result.success(null)
                }
                "cancelAllNotifications" -> {
                    cancelAllNotifications()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // 设置 MethodChannel 引用到 CompleteActionReceiver
        CompleteActionReceiver.setMethodChannel(methodChannel!!)
        
        // 如果有待处理的详情页请求
        initialMemoryIdHash?.let {
            Handler(Looper.getMainLooper()).postDelayed({
                methodChannel?.invokeMethod("onOpenDetail", mapOf("id" to it))
                initialMemoryIdHash = null
            }, 500)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "待办事项",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "显示待处理的记忆事项"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun getCategoryIcon(category: String): Bitmap {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        val bgColor = when (category) {
            "取餐码" -> Color.parseColor("#FF9500")
            "取件码" -> Color.parseColor("#34C759")
            "账单" -> Color.parseColor("#007AFF")
            else -> Color.parseColor("#8E8E93")
        }
        
        val paint = Paint().apply {
            color = bgColor
            style = Paint.Style.FILL
            isAntiAlias = true
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        
        val iconPaint = Paint().apply {
            color = Color.WHITE
            textSize = 40f
            isAntiAlias = true
            textAlign = Paint.Align.CENTER
        }
        
        val text = when (category) {
            "取餐码" -> "餐"
            "取件码" -> "件"
            "账单" -> "¥"
            else -> "记"
        }
        
        val textBounds = android.graphics.Rect()
        iconPaint.getTextBounds(text, 0, text.length, textBounds)
        canvas.drawText(text, size / 2f, size / 2f + textBounds.height() / 2f, iconPaint)
        
        return bitmap
    }

    private fun showLiveUpdateNotification(id: Int, title: String, category: String) {
        Log.d("MainActivity", "showLiveUpdateNotification 开始: id=$id, title=$title, category=$category")
        
        // 点击通知打开详情页的 Intent
        val openDetailIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("memory_id_hash", id)
        }
        val openDetailPendingIntent = PendingIntent.getActivity(
            this,
            id * 2,
            openDetailIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 完成按钮的 Intent - 使用 BroadcastReceiver
        val completeIntent = Intent(ACTION_COMPLETE).apply {
            putExtra("memory_id_hash", id)
            setPackage(packageName)
        }
        val completePendingIntent = PendingIntent.getBroadcast(
            this,
            id * 2 + 1,
            completeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val largeIcon = getCategoryIcon(category)
        Log.d("MainActivity", "图标创建完成: ${largeIcon.width}x${largeIcon.height}")

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_agenda)
            .setLargeIcon(largeIcon)
            .setContentTitle(title)
            .setContentText(category)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(title)
                    .setSummaryText(category)
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openDetailPendingIntent)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setGroup(NOTIFICATION_GROUP_KEY)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "已完成",
                completePendingIntent
            )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setRequestPromotedOngoing(true)
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(id, builder.build())
        Log.d("MainActivity", "通知已发送: id=$id")
    }

    private fun cancelNotification(id: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id)
    }

    private fun cancelAllNotifications() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancelAll()
    }
}
