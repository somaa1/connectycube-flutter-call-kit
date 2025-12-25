package com.connectycube.flutter.connectycube_flutter_call_kit.utils

import android.content.Context

/**
 * Legacy SharedPreferences utility functions.
 *
 * DEPRECATED: This file now delegates to ThreadSafePreferences for backwards compatibility.
 * New code should use ThreadSafePreferences directly for better performance and clarity.
 *
 * MIGRATION HISTORY:
 * - v2.x: Original implementation with race conditions (module-level mutable state)
 * - v3.0: Refactored to delegate to ThreadSafePreferences (thread-safe, no breaking changes)
 *
 * WHY THIS CHANGE WAS NEEDED:
 * The original implementation created a new Editor instance on every call, leading to:
 * - Race conditions when multiple threads accessed SharedPreferences
 * - Data corruption when Editor instances overlapped
 * - Lost updates when concurrent writes occurred
 *
 * The new implementation uses:
 * - ReentrantReadWriteLock for thread safety
 * - Single SharedPreferences instance
 * - No mutable global state
 * - Proper error handling and logging
 *
 * @author ConnectyCube (Refactored for Production v3.0)
 * @deprecated Use ThreadSafePreferences directly for better performance
 */

// Legacy function signatures maintained for backwards compatibility

@Deprecated(
    message = "Use ThreadSafePreferences.putBoolean() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.putBoolean(key, value)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun putBoolean(context: Context, key: String, value: Boolean) {
    ThreadSafePreferences.init(context)
    ThreadSafePreferences.putBoolean(key, value)
}

@Deprecated(
    message = "Use ThreadSafePreferences.getBoolean() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.getBoolean(key)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun getBoolean(context: Context, key: String): Boolean {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getBoolean(key, false)
}

@Deprecated(
    message = "Use ThreadSafePreferences.putString() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.putString(key, value)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun putString(context: Context, key: String, value: String?) {
    ThreadSafePreferences.init(context)
    ThreadSafePreferences.putString(key, value)
}

@Deprecated(
    message = "Use ThreadSafePreferences.getString() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.getString(key)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun getString(context: Context, key: String): String? {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getString(key, "")
}

@Deprecated(
    message = "Use ThreadSafePreferences.putInt() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.putInt(key, value)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun putInt(context: Context, key: String, value: Int) {
    ThreadSafePreferences.init(context)
    ThreadSafePreferences.putInt(key, value)
}

@Deprecated(
    message = "Use ThreadSafePreferences.getInt() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.getInt(key, -1)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun getInt(context: Context, key: String): Int {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getInt(key, -1)
}

@Deprecated(
    message = "Use ThreadSafePreferences.putLong() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.putLong(key, value)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun putLong(context: Context, key: String, value: Long) {
    ThreadSafePreferences.init(context)
    ThreadSafePreferences.putLong(key, value)
}

@Deprecated(
    message = "Use ThreadSafePreferences.getLong() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.getLong(key, -1L)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun getLong(context: Context, key: String): Long {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getLong(key, -1L)
}

@Deprecated(
    message = "Use ThreadSafePreferences.putDouble() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.putDouble(key, value)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun putDouble(context: Context, key: String, value: Double) {
    ThreadSafePreferences.init(context)
    ThreadSafePreferences.putDouble(key, value)
}

@Deprecated(
    message = "Use ThreadSafePreferences.getDouble() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.getDouble(key, 0.0)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun getDouble(context: Context, key: String): Double {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getDouble(key, 0.0)
}

@Deprecated(
    message = "Use ThreadSafePreferences.remove() directly",
    replaceWith = ReplaceWith(
        "ThreadSafePreferences.remove(key)",
        "com.connectycube.flutter.connectycube_flutter_call_kit.utils.ThreadSafePreferences"
    )
)
fun remove(context: Context, key: String) {
    ThreadSafePreferences.init(context)
    ThreadSafePreferences.remove(key)
}

// ==================== IMAGE CONFIGURATION HELPERS ====================
// These are NOT deprecated as they provide domain-specific logic

/**
 * Get image loading timeout configuration.
 *
 * @param context Android context (used for initialization)
 * @return Timeout in milliseconds (default: 10000ms = 10s)
 */
fun getImageLoadingTimeout(context: Context): Int {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getImageLoadingTimeout()
}

/**
 * Get image caching enabled configuration.
 *
 * @param context Android context (used for initialization)
 * @return true if caching is enabled, false otherwise
 */
fun getImageCachingEnabled(context: Context): Boolean {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getImageCachingEnabled()
}

/**
 * Get maximum image size configuration.
 *
 * @param context Android context (used for initialization)
 * @return Max size in pixels (default: 300px)
 */
fun getMaxImageSize(context: Context): Int {
    ThreadSafePreferences.init(context)
    return ThreadSafePreferences.getMaxImageSize()
}
