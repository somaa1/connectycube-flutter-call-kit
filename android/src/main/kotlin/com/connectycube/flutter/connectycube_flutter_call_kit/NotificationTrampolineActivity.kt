package com.connectycube.flutter.connectycube_flutter_call_kit

import android.app.Activity
import android.os.Bundle
import android.content.Intent
import android.util.Log

/**
 * Trampoline activity for handling notification actions in Android 12+.
 * This activity launches immediately and delegates to EventReceiver.
 *
 * PRODUCTION IMPROVEMENTS (v3.0):
 * - Added null safety checks (no more force-unwraps)
 * - Added comprehensive error logging
 * - Handles missing extras gracefully
 * - Always finishes to prevent memory leaks
 */
class NotificationTrampolineActivity : Activity() {
    companion object {
        private const val TAG = "NotificationTrampoline"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            handleNotificationAction()
        } catch (e: Exception) {
            Log.e(TAG, "Error handling notification action", e)
        } finally {
            // Always finish, even if there's an error
            finishAndRemoveTask()
        }
    }

    private fun handleNotificationAction() {
        val action = intent?.action

        if (action == null) {
            Log.w(TAG, "Intent action is null, cannot process notification")
            return
        }

        if (action == ACTION_CALL_ACCEPT) {
            val extras = intent.extras

            if (extras == null) {
                Log.e(TAG, "Intent extras are null for ACTION_CALL_ACCEPT")
                return
            }

            val callId = extras.getString(EXTRA_CALL_ID)
            if (callId == null) {
                Log.e(TAG, "Call ID is missing from intent extras")
                return
            }

            Log.d(TAG, "Processing ACTION_CALL_ACCEPT for call: $callId")

            try {
                val startCallIntent = Intent(this, EventReceiver::class.java).apply {
                    this.action = ACTION_CALL_ACCEPT
                    putExtras(extras)
                }

                applicationContext.sendBroadcast(startCallIntent)
                Log.d(TAG, "Broadcast sent successfully for call: $callId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send broadcast for call: $callId", e)
            }
        } else {
            Log.w(TAG, "Unknown action: $action")
        }
    }
}
