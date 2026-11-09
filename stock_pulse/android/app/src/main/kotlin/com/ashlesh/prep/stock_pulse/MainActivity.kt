package com.ashlesh.prep.stock_pulse

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.content.Intent
import android.net.Uri

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val permissionRequestCode = 7412
    private val askedKey = "notification_permission_asked"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SpHaptics(this).attach(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stock_pulse/push_permission")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(notificationStatus())
                    "request" -> requestNotificationPermission(result)
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun notificationStatus(): String {
        if (Build.VERSION.SDK_INT < 33) return "granted"
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return "granted"
        // Android has no public "never asked" flag, so remember our own request.
        val askedBefore = getPreferences(MODE_PRIVATE).getBoolean(askedKey, false)
        return if (askedBefore || shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS))
            "denied" else "notDetermined"
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || notificationStatus() == "granted") {
            result.success("granted")
            return
        }
        permissionResult = result
        getPreferences(MODE_PRIVATE).edit().putBoolean(askedKey, true).apply()
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            permissionResult?.success(if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) "granted" else "denied")
            permissionResult = null
        }
    }
}
