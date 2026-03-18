package com.maliang.maliang_notes

import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import android.util.Log

class QuickTileService : TileService() {

    companion object {
        private const val TAG = "QuickTileService"
    }

    override fun onStartListening() {
        super.onStartListening()
        // 磁贴可见时更新状态
        qsTile?.let {
            it.state = android.service.quicksettings.Tile.STATE_INACTIVE
            it.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        Log.d(TAG, "磁贴被点击")

        val intent = Intent(this, TilePickerActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(android.app.PendingIntent.getActivity(
                this, 0, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            ))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
