package com.connectycube.flutter.connectycube_flutter_call_kit.utils

import android.app.Activity
import android.app.Application
import android.app.KeyguardManager
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import androidx.lifecycle.ProcessLifecycleOwner
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Production-grade app lifecycle tracker using ProcessLifecycleOwner.
 *
 * PROBLEM SOLVED:
 * The old implementation used ActivityManager.runningAppProcesses which is:
 * - DEPRECATED since Android Q (API 29)
 * - BROKEN on Android 10+ due to privacy restrictions
 * - Returns empty/incorrect results on modern devices
 *
 * NEW SOLUTION:
 * - Uses ProcessLifecycleOwner (AndroidX Lifecycle)
 * - Works reliably on all Android versions (API 14+)
 * - No privacy restrictions
 * - Lifecycle-aware and efficient
 *
 * USAGE:
 * ```kotlin
 * // Initialize once in Application.onCreate()
 * AppLifecycleTracker.init(application)
 *
 * // Query foreground state anytime
 * val isForeground = AppLifecycleTracker.isApplicationInForeground(context)
 * ```
 *
 * @author ConnectyCube (Production Edition v3.0)
 */
object AppLifecycleTracker : LifecycleObserver, Application.ActivityLifecycleCallbacks {
    private const val TAG = "AppLifecycleTracker"

    // Thread-safe atomic flags
    private val isInForeground = AtomicBoolean(false)
    private val isInitialized = AtomicBoolean(false)
    private var activeActivityCount = 0

    /**
     * Initialize the lifecycle tracker.
     * Call this ONCE in Application.onCreate()
     *
     * @param application The application instance
     */
    fun init(application: Application) {
        if (isInitialized.getAndSet(true)) {
            Log.d(TAG, "Already initialized, skipping")
            return
        }

        Log.d(TAG, "Initializing AppLifecycleTracker")

        // Register for process lifecycle events
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)

        // Register for activity lifecycle events
        application.registerActivityLifecycleCallbacks(this)

        Log.d(TAG, "AppLifecycleTracker initialized successfully")
    }

    /**
     * Check if the application is in the foreground.
     *
     * This considers TWO conditions:
     * 1. Process is in foreground (visible to user)
     * 2. Device is not locked (keyguard not showing)
     *
     * @param context Android context (used for keyguard check)
     * @return true if app is in foreground AND device is unlocked
     */
    fun isApplicationInForeground(context: Context): Boolean {
        // Check if process is in foreground
        if (!isInForeground.get()) {
            return false
        }

        // Check if device is locked
        if (isDeviceLocked(context)) {
            return false
        }

        return true
    }

    /**
     * Get the raw foreground state without keyguard check.
     *
     * @return true if process is in foreground (may be behind lock screen)
     */
    fun isProcessInForeground(): Boolean {
        return isInForeground.get()
    }

    /**
     * Check if the device is locked (keyguard showing).
     *
     * @param context Android context
     * @return true if device is locked
     */
    private fun isDeviceLocked(context: Context): Boolean {
        return try {
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.isKeyguardLocked ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking keyguard state", e)
            false
        }
    }

    // ==================== LIFECYCLE CALLBACKS ====================

    @OnLifecycleEvent(Lifecycle.Event.ON_START)
    fun onMoveToForeground() {
        isInForeground.set(true)
        Log.d(TAG, "App moved to FOREGROUND")
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    fun onMoveToBackground() {
        isInForeground.set(false)
        Log.d(TAG, "App moved to BACKGROUND")
    }

    // ==================== ACTIVITY LIFECYCLE CALLBACKS ====================
    // Used for finer-grained tracking if needed

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        Log.v(TAG, "Activity created: ${activity.javaClass.simpleName}")
    }

    override fun onActivityStarted(activity: Activity) {
        activeActivityCount++
        Log.v(TAG, "Activity started: ${activity.javaClass.simpleName}, active count: $activeActivityCount")
    }

    override fun onActivityResumed(activity: Activity) {
        Log.v(TAG, "Activity resumed: ${activity.javaClass.simpleName}")
    }

    override fun onActivityPaused(activity: Activity) {
        Log.v(TAG, "Activity paused: ${activity.javaClass.simpleName}")
    }

    override fun onActivityStopped(activity: Activity) {
        activeActivityCount--
        Log.v(TAG, "Activity stopped: ${activity.javaClass.simpleName}, active count: $activeActivityCount")
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        // No action needed
    }

    override fun onActivityDestroyed(activity: Activity) {
        Log.v(TAG, "Activity destroyed: ${activity.javaClass.simpleName}")
    }

    /**
     * Get the number of active activities.
     * Useful for debugging.
     *
     * @return Number of activities in started state
     */
    fun getActiveActivityCount(): Int {
        return activeActivityCount
    }
}
