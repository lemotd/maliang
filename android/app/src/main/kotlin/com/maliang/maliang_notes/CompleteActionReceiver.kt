package com.maliang.maliang_notes

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class CompleteActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val memoryIdHash = intent.getIntExtra("memory_id_hash", 0)
        Log.d("CompleteActionReceiver", "收到完成请求: $memoryIdHash")
        
        // 取消通知
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(memoryIdHash)
        
        // 保存完成请求到 SharedPreferences
        val prefs = context.getSharedPreferences("pending_actions", Context.MODE_PRIVATE)
        val pendingCompletes = prefs.getStringSet("pending_completes", emptySet())?.toMutableSet() ?: mutableSetOf()
        pendingCompletes.add(memoryIdHash.toString())
        prefs.edit().putStringSet("pending_completes", pendingCompletes).apply()
        
        Log.d("CompleteActionReceiver", "已保存完成请求: $memoryIdHash")
    }
}
