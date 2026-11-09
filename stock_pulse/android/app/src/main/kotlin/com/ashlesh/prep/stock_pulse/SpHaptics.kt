package com.ashlesh.prep.stock_pulse

import android.app.Activity
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.HapticFeedbackConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Order-outcome haptics on channel `stockpulse/haptics` (FR-100).
 * Methods `success` and `rejection`, no args. Always answers `success(null)`;
 * a device without a vibrator does nothing. Unknown methods → notImplemented.
 * Flutter delivers platform-channel calls on the main thread.
 */
class SpHaptics(private val activity: Activity) : MethodChannel.MethodCallHandler {

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "success" -> {
                play(success = true)
                result.success(null)
            }
            "rejection" -> {
                play(success = false)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun play(success: Boolean) {
        val vibrator: Vibrator? = activity.getSystemService(Vibrator::class.java)
        if (vibrator == null || !vibrator.hasVibrator()) return
        val view = activity.window?.decorView ?: return
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> view.performHapticFeedback(
                if (success) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.REJECT
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                val effect = if (success) {
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 25, 80, 15), intArrayOf(0, 180, 0, 90), -1
                    )
                } else {
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 40, 120, 40), intArrayOf(0, 255, 0, 255), -1
                    )
                }
                vibrator.vibrate(effect)
            }
            else -> view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        }
    }

    private companion object {
        const val CHANNEL = "stockpulse/haptics"
    }
}
