package com.maliang.maliang_notes

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class CompleteActionReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL = "com.maliang.maliang_notes/notification"
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val memoryIdHash = intent.getIntExtra("memory_id_hash", 0)
        Log.d("CompleteActionReceiver", "收到完成请求: $memoryIdHash")
        
        // 取消通知
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(memoryIdHash)
        
        // 直接通过 MethodChannel 通知 Flutter
        try {
            methodChannel?.invokeMethod("onCompleteMemory", mapOf("id" to memoryIdHash))
            Log.d("CompleteActionReceiver", "已通知 Flutter 完成: $memoryIdHash")
        } catch (e: Exception) {
            Log.e("CompleteActionReceiver", "通知 Flutter 失败: $e")
            // 如果失败，保存到 SharedPreferences
            val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
            val pendingCompletes = prefs.getStringSet("pending_completes", emptySet())?.toMutableSet() ?: mutableSetOf()
            pendingCompletes.add(memoryIdHash.toString())
            prefs.edit().putStringSet("pending_completes", pendingCompletes).apply()
            Log.d("CompleteActionReceiver", "已保存完成请求: $memoryIdHash")
        }
    }
}
