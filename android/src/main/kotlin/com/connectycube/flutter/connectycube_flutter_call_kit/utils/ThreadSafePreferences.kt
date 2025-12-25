package com.connectycube.flutter.connectycube_flutter_call_kit.utils

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Thread-safe wrapper for SharedPreferences operations.
 *
 * This class addresses critical race conditions in the original SharedPrefsUtils implementation
 * where multiple threads could create overlapping Editor instances, causing data corruption.
 *
 * Key improvements:
 * - Read-write lock for optimal concurrent read performance
 * - Single SharedPreferences instance (properly initialized once)
 * - No mutable global state for editors
 * - Atomic operations with proper synchronization
 * - Comprehensive error logging
 *
 * Thread Safety Guarantees:
 * - Multiple threads can read simultaneously (ReentrantReadWriteLock.read)
 * - Writes are exclusive (ReentrantReadWriteLock.write)
 * - No race conditions between reads and writes
 * - No lost updates
 *
 * @author ConnectyCube (Production-Ready Edition)
 * @version 3.0.0
 */
object ThreadSafePreferences {
    private const val TAG = "ThreadSafePreferences"
    private const val PREFERENCES_FILE_NAME = "connectycube_flutter_call_kit"

    // Read-write lock for optimal concurrent performance
    // Allows multiple simultaneous readers, but exclusive writers
    private val lock = ReentrantReadWriteLock()

    // Lazy initialization with thread safety
    private lateinit var preferences: SharedPreferences
    private var isInitialized = false

    /**
     * Initialize the SharedPreferences instance.
     * This must be called before any other operations.
     * Safe to call multiple times - only initializes once.
     *
     * @param context Application context (will use applicationContext)
     */
    @Synchronized
    fun init(context: Context) {
        if (!isInitialized) {
            preferences = context.applicationContext.getSharedPreferences(
                PREFERENCES_FILE_NAME,
                Context.MODE_PRIVATE
            )
            isInitialized = true
            Log.d(TAG, "Initialized SharedPreferences: $PREFERENCES_FILE_NAME")
        }
    }

    /**
     * Ensure preferences are initialized.
     * Throws if not initialized with proper context.
     */
    private fun ensureInitialized() {
        check(isInitialized) {
            "ThreadSafePreferences not initialized! Call init(context) first."
        }
    }

    // ==================== BOOLEAN OPERATIONS ====================

    /**
     * Store a boolean value with thread safety.
     *
     * @param key The key to store under
     * @param value The boolean value to store
     * @return true if successful, false otherwise
     */
    fun putBoolean(key: String, value: Boolean): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                preferences.edit().putBoolean(key, value).apply()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put boolean for key: $key", e)
            false
        }
    }

    /**
     * Retrieve a boolean value with thread safety.
     *
     * @param key The key to retrieve
     * @param defaultValue Value to return if key doesn't exist (default: false)
     * @return The stored boolean value or defaultValue
     */
    fun getBoolean(key: String, defaultValue: Boolean = false): Boolean {
        return try {
            lock.read {
                ensureInitialized()
                preferences.getBoolean(key, defaultValue)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get boolean for key: $key, returning default: $defaultValue", e)
            defaultValue
        }
    }

    // ==================== STRING OPERATIONS ====================

    /**
     * Store a string value with thread safety.
     *
     * @param key The key to store under
     * @param value The string value to store (null will remove the key)
     * @return true if successful, false otherwise
     */
    fun putString(key: String, value: String?): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                if (value == null) {
                    preferences.edit().remove(key).apply()
                } else {
                    preferences.edit().putString(key, value).apply()
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put string for key: $key", e)
            false
        }
    }

    /**
     * Retrieve a string value with thread safety.
     *
     * @param key The key to retrieve
     * @param defaultValue Value to return if key doesn't exist (default: empty string)
     * @return The stored string value or defaultValue
     */
    fun getString(key: String, defaultValue: String = ""): String {
        return try {
            lock.read {
                ensureInitialized()
                preferences.getString(key, defaultValue) ?: defaultValue
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get string for key: $key, returning default", e)
            defaultValue
        }
    }

    // ==================== INTEGER OPERATIONS ====================

    /**
     * Store an integer value with thread safety.
     *
     * @param key The key to store under
     * @param value The integer value to store
     * @return true if successful, false otherwise
     */
    fun putInt(key: String, value: Int): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                preferences.edit().putInt(key, value).apply()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put int for key: $key", e)
            false
        }
    }

    /**
     * Retrieve an integer value with thread safety.
     *
     * @param key The key to retrieve
     * @param defaultValue Value to return if key doesn't exist (default: -1)
     * @return The stored integer value or defaultValue
     */
    fun getInt(key: String, defaultValue: Int = -1): Int {
        return try {
            lock.read {
                ensureInitialized()
                preferences.getInt(key, defaultValue)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get int for key: $key, returning default: $defaultValue", e)
            defaultValue
        }
    }

    // ==================== LONG OPERATIONS ====================

    /**
     * Store a long value with thread safety.
     *
     * @param key The key to store under
     * @param value The long value to store
     * @return true if successful, false otherwise
     */
    fun putLong(key: String, value: Long): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                preferences.edit().putLong(key, value).apply()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put long for key: $key", e)
            false
        }
    }

    /**
     * Retrieve a long value with thread safety.
     *
     * @param key The key to retrieve
     * @param defaultValue Value to return if key doesn't exist (default: -1L)
     * @return The stored long value or defaultValue
     */
    fun getLong(key: String, defaultValue: Long = -1L): Long {
        return try {
            lock.read {
                ensureInitialized()
                preferences.getLong(key, defaultValue)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get long for key: $key, returning default: $defaultValue", e)
            defaultValue
        }
    }

    // ==================== DOUBLE OPERATIONS ====================

    /**
     * Store a double value with thread safety.
     * Note: Stored as string since SharedPreferences doesn't support double natively.
     *
     * @param key The key to store under
     * @param value The double value to store
     * @return true if successful, false otherwise
     */
    fun putDouble(key: String, value: Double): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                preferences.edit().putString(key, value.toString()).apply()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to put double for key: $key", e)
            false
        }
    }

    /**
     * Retrieve a double value with thread safety.
     *
     * @param key The key to retrieve
     * @param defaultValue Value to return if key doesn't exist (default: 0.0)
     * @return The stored double value or defaultValue
     */
    fun getDouble(key: String, defaultValue: Double = 0.0): Double {
        return try {
            lock.read {
                ensureInitialized()
                val stringValue = preferences.getString(key, null)
                stringValue?.toDoubleOrNull() ?: defaultValue
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get double for key: $key, returning default: $defaultValue", e)
            defaultValue
        }
    }

    // ==================== REMOVAL OPERATIONS ====================

    /**
     * Remove a key from SharedPreferences with thread safety.
     *
     * @param key The key to remove
     * @return true if successful, false otherwise
     */
    fun remove(key: String): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                preferences.edit().remove(key).apply()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove key: $key", e)
            false
        }
    }

    /**
     * Clear all preferences with thread safety.
     * USE WITH CAUTION - This removes ALL stored data!
     *
     * @return true if successful, false otherwise
     */
    fun clear(): Boolean {
        return try {
            lock.write {
                ensureInitialized()
                preferences.edit().clear().apply()
            }
            Log.w(TAG, "All preferences cleared!")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear preferences", e)
            false
        }
    }

    // ==================== QUERY OPERATIONS ====================

    /**
     * Check if a key exists in preferences.
     *
     * @param key The key to check
     * @return true if key exists, false otherwise
     */
    fun contains(key: String): Boolean {
        return try {
            lock.read {
                ensureInitialized()
                preferences.contains(key)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check key existence: $key", e)
            false
        }
    }

    /**
     * Get all keys in preferences.
     * WARNING: Can be expensive for large preference sets.
     *
     * @return Set of all keys
     */
    fun getAllKeys(): Set<String> {
        return try {
            lock.read {
                ensureInitialized()
                preferences.all.keys
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get all keys", e)
            emptySet()
        }
    }

    // ==================== HELPER METHODS ====================

    /**
     * Get image loading timeout configuration.
     *
     * @return Timeout in milliseconds (default: 10000ms = 10s)
     */
    fun getImageLoadingTimeout(): Int {
        val timeout = getInt("image_loading_timeout", 10000)
        return if (timeout > 0) timeout else 10000
    }

    /**
     * Get image caching enabled configuration.
     *
     * @return true if caching is enabled, false otherwise
     */
    fun getImageCachingEnabled(): Boolean {
        return getBoolean("enable_image_caching", false)
    }

    /**
     * Get maximum image size configuration.
     *
     * @return Max size in pixels (default: 300px)
     */
    fun getMaxImageSize(): Int {
        val size = getInt("max_image_size", 300)
        return if (size > 0) size else 300
    }
}
