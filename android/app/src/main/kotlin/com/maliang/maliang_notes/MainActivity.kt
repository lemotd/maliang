package com.maliang.maliang_notes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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
    private val CALENDAR_CHANNEL = "com.maliang.notes/calendar"
    private val NOTIFICATION_CHANNEL_ID = "memory_live_update"
    private val NOTIFICATION_GROUP_KEY = "com.maliang.maliang_notes.pending_group"
    private val ACTION_COMPLETE = "com.maliang.maliang_notes.ACTION_COMPLETE"
    
    companion object {
        var methodChannelInstance: MethodChannel? = null
            private set
        var isEngineActive: Boolean = false
            private set
    }

    private var initialMemoryIdHash: Int? = null
    private var pendingTileImagePath: String? = null

    // 是否是从磁贴后台启动的（不应显示界面）
    private var launchedFromTile: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super.onCreate 之前处理 Intent，
        // 因为 super.onCreate 会触发 configureFlutterEngine，
        // 此时 pendingTileImagePath 需要已经设置好
        handleIncomingIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        // 如果是从磁贴后台启动的，立即回到后台
        if (launchedFromTile) {
            launchedFromTile = false
            moveTaskToBack(true)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        intent ?: return
        // 处理通知点击打开详情
        val memoryIdHash = intent.getIntExtra("memory_id_hash", -1)
        if (memoryIdHash != -1) {
            initialMemoryIdHash = memoryIdHash
            methodChannelInstance?.invokeMethod("onOpenDetail", mapOf("id" to memoryIdHash))
        }
        // 处理磁贴图片（后台启动时传入）
        val tileImagePath = intent.getStringExtra("tile_image_path")
        if (tileImagePath != null) {
            intent.removeExtra("tile_image_path") // 防止重复处理
            pendingTileImagePath = tileImagePath
            launchedFromTile = true
            // 如果引擎已就绪，立即发送
            if (isEngineActive && methodChannelInstance != null) {
                Handler(Looper.getMainLooper()).post {
                    methodChannelInstance?.invokeMethod("onTileImage", mapOf("path" to tileImagePath))
                    pendingTileImagePath = null
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        createNotificationChannel()
        isEngineActive = true
        
        methodChannelInstance = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannelInstance?.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "收到方法调用: ${call.method}")
            when (call.method) {
                "showLiveUpdateNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val category = call.argument<String>("category") ?: ""
                    val detail = call.argument<String>("detail") ?: ""
                    Log.d("MainActivity", "显示通知: id=$id, title=$title, category=$category, detail=$detail")
                    showLiveUpdateNotification(id, title, category, detail)
                    result.success(null)
                }
                "showProcessingNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    AiProcessingService.start(this)
                    result.success(null)
                }
                "cancelNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    // 如果取消的是处理中通知，停止前台服务
                    if (id == 99999) {
                        AiProcessingService.stop(this)
                    } else {
                        cancelNotification(id)
                    }
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
        CompleteActionReceiver.setMethodChannel(methodChannelInstance!!)

        // 日历 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addEvent" -> {
                        val title = call.argument<String>("title") ?: ""
                        val startTime = call.argument<Long>("startTime") ?: 0L
                        val endTime = call.argument<Long>("endTime") ?: 0L
                        addCalendarEvent(title, startTime, endTime)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // 如果有待处理的详情页请求
        initialMemoryIdHash?.let {
            Handler(Looper.getMainLooper()).postDelayed({
                methodChannelInstance?.invokeMethod("onOpenDetail", mapOf("id" to it))
                initialMemoryIdHash = null
            }, 500)
        }

        // 检查 SharedPreferences 中是否有未处理的磁贴图片（兜底机制）
        val prefs = getSharedPreferences(TilePickerActivity.PREFS_NAME, Context.MODE_PRIVATE)
        val savedPath = prefs.getString(TilePickerActivity.KEY_PENDING_IMAGE, null)
        if (savedPath != null) {
            prefs.edit().remove(TilePickerActivity.KEY_PENDING_IMAGE).apply()
            // 只有当 Intent 没有传入图片路径时才使用 SharedPreferences 的路径
            if (pendingTileImagePath == null) {
                pendingTileImagePath = savedPath
            }
        }

        // 发送待处理的磁贴图片
        if (pendingTileImagePath != null) {
            val path = pendingTileImagePath
            pendingTileImagePath = null
            Handler(Looper.getMainLooper()).postDelayed({
                methodChannelInstance?.invokeMethod("onTileImage", mapOf("path" to path))
            }, 800)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        isEngineActive = false
        methodChannelInstance = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        // 确保前台服务也被停止
        AiProcessingService.stop(this)
        super.onDestroy()
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

    private fun getCategoryIconRes(category: String): Int {
        return when (category) {
            "取餐码" -> R.drawable.ic_pickup_food
            "取件码" -> R.drawable.ic_pickup_package
            "账单" -> R.drawable.ic_bill
            "服饰" -> R.drawable.ic_clothing
            else -> R.drawable.ic_note
        }
    }

    private fun showLiveUpdateNotification(id: Int, title: String, category: String, detail: String) {
        Log.d("MainActivity", "showLiveUpdateNotification 开始: id=$id, title=$title, category=$category, detail=$detail")
        
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

        val iconRes = getCategoryIconRes(category)
        Log.d("MainActivity", "使用图标资源: $iconRes")

        // 构建通知内容
        val contentText = if (detail.isNotEmpty()) "$category · $detail" else category
        
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(contentText)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(contentText)
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

    private fun addCalendarEvent(title: String, startTime: Long, endTime: Long) {
        val intent = Intent(Intent.ACTION_INSERT).apply {
            data = android.provider.CalendarContract.Events.CONTENT_URI
            putExtra(android.provider.CalendarContract.Events.TITLE, title)
            putExtra(android.provider.CalendarContract.EXTRA_EVENT_BEGIN_TIME, startTime)
            putExtra(android.provider.CalendarContract.EXTRA_EVENT_END_TIME, endTime)
        }
        startActivity(intent)
    }
}
