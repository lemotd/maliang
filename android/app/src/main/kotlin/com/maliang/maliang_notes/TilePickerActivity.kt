package com.maliang.maliang_notes

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import java.io.File
import java.io.FileOutputStream

class TilePickerActivity : Activity() {

    companion object {
        private const val TAG = "TilePickerActivity"
        private const val PICK_IMAGE_REQUEST = 1001
        const val PREFS_NAME = "tile_prefs"
        const val KEY_PENDING_IMAGE = "pending_image_path"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
        }
        startActivityForResult(intent, PICK_IMAGE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            if (resultCode == RESULT_OK && data?.data != null) {
                Log.d(TAG, "选择了图片: ${data.data}")
                handleImage(data.data!!)
            } else {
                Log.d(TAG, "用户取消选择")
            }
            finish()
        }
    }

    private fun handleImage(uri: Uri) {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return
            val tempFile = File(cacheDir, "tile_${System.currentTimeMillis()}.jpg")
            FileOutputStream(tempFile).use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()

            val path = tempFile.absolutePath
            Log.d(TAG, "图片已复制到: $path")

            // 存到 SharedPreferences（兜底，下次打开应用时处理）
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING_IMAGE, path)
                .apply()

            // 启动前台服务处理图片（会自动选择用主 FlutterEngine 或后台 FlutterEngine）
            AiProcessingService.startWithImage(this, path)

        } catch (e: Exception) {
            Log.e(TAG, "处理图片失败: $e")
        }
    }
}
