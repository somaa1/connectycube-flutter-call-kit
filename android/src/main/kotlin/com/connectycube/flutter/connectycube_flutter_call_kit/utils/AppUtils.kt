package com.connectycube.flutter.connectycube_flutter_call_kit.utils

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Application utility functions.
 *
 * PRODUCTION IMPROVEMENTS (v3.0):
 * - Fixed foreground detection for Android 10+ (API 29+)
 * - Added lifecycle-aware detection using AppLifecycleTracker
 * - Deprecated old implementation (kept for backwards compatibility)
 * - Added comprehensive error handling and logging
 *
 * MIGRATION GUIDE:
 * Old: isApplicationForeground(context)  // Broken on Android 10+
 * New: AppLifecycleTracker.init(application) in Application.onCreate()
 *      AppLifecycleTracker.isApplicationInForeground(context)
 *
 * The isApplicationForeground() function now automatically uses the new implementation
 * if AppLifecycleTracker is initialized, otherwise falls back to the old method.
 */

private const val TAG = "AppUtils"

/**
 * Identify if the application is currently in a state where user interaction is possible.
 *
 * IMPORTANT: This function is deprecated on Android 10+ (API 29+) due to privacy restrictions.
 * Use AppLifecycleTracker.init() in your Application class for reliable foreground detection.
 *
 * This method now automatically delegates to AppLifecycleTracker if initialized,
 * otherwise uses the legacy implementation as fallback.
 *
 * @param context Android context
 * @return true if app is in foreground and device is unlocked, false otherwise
 */
fun isApplicationForeground(context: Context): Boolean {
    return try {
        // Try new lifecycle-aware implementation first
        AppLifecycleTracker.isApplicationInForeground(context)
    } catch (e: IllegalStateException) {
        // AppLifecycleTracker not initialized, fall back to legacy method
        Log.w(TAG, "AppLifecycleTracker not initialized, using legacy foreground detection. " +
                "This may not work correctly on Android 10+. " +
                "Call AppLifecycleTracker.init(application) in your Application.onCreate().")
        isApplicationForegroundLegacy(context)
    } catch (e: Exception) {
        Log.e(TAG, "Error checking foreground state", e)
        false
    }
}

/**
 * Legacy foreground detection implementation.
 *
 * WARNING: This method is BROKEN on Android 10+ (API 29+) due to privacy restrictions.
 * ActivityManager.runningAppProcesses returns limited information on modern Android versions.
 *
 * DO NOT USE directly - use isApplicationForeground() instead, which automatically
 * uses the new lifecycle-aware implementation when available.
 *
 * @param context Android context
 * @return true if detected as foreground (unreliable on Android 10+)
 */
@Deprecated(
    message = "This implementation is broken on Android 10+. Use AppLifecycleTracker instead.",
    replaceWith = ReplaceWith(
        "AppLifecycleTracker.isApplicationInForeground(context)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.AppLifecycleTracker"
    ),
    level = DeprecationLevel.WARNING
)
private fun isApplicationForegroundLegacy(context: Context): Boolean {
    // Check if device is locked first
    val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
    if (keyguardManager == null) {
        Log.w(TAG, "KeyguardManager is null")
        return false
    }

    if (keyguardManager.isKeyguardLocked) {
        Log.d(TAG, "Device is locked (keyguard active)")
        return false
    }

    // Get activity manager
    val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
    if (activityManager == null) {
        Log.w(TAG, "ActivityManager is null")
        return false
    }

    // WARNING: This API is limited on Android 10+ (API 29+)
    // It only returns information about the app's own processes
    val appProcesses = activityManager.runningAppProcesses

    if (appProcesses == null) {
        Log.w(TAG, "runningAppProcesses is null (likely Android 10+ privacy restriction)")
        return false
    }

    if (appProcesses.isEmpty()) {
        Log.w(TAG, "runningAppProcesses is empty (likely Android 10+ privacy restriction)")
        return false
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        Log.w(TAG, "Using legacy foreground detection on Android 10+. This may not work correctly. " +
                "Initialize AppLifecycleTracker in your Application class.")
    }

    val packageName = context.packageName
    for (appProcess in appProcesses) {
        if (appProcess.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
            && appProcess.processName == packageName
        ) {
            Log.d(TAG, "App detected as foreground (legacy method)")
            return true
        }
    }

    Log.d(TAG, "App not in foreground (legacy method)")
    return false
}

/**
 * Check if the device screen is locked.
 *
 * @param context Android context
 * @return true if device is locked
 */
fun isDeviceLocked(context: Context): Boolean {
    return try {
        val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        keyguardManager?.isKeyguardLocked ?: false
    } catch (e: Exception) {
        Log.e(TAG, "Error checking device lock state", e)
        false
    }
}
