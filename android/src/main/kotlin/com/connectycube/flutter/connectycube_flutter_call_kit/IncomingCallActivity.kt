package com.connectycube.flutter.connectycube_flutter_call_kit

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView
import android.widget.RelativeLayout
import android.widget.LinearLayout
import android.graphics.Color
import androidx.annotation.Nullable
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.bumptech.glide.Glide
import com.connectycube.flutter.connectycube_flutter_call_kit.utils.getPhotoPlaceholderResId
import com.google.android.material.imageview.ShapeableImageView
import com.skyfishjy.library.RippleBackground


fun createStartIncomingScreenIntent(
    context: Context, callId: String, callType: Int, callInitiatorId: Int,
    callInitiatorName: String, opponents: ArrayList<Int>, callPhoto: String?, userInfo: String,
    customBodyText: String? = null
): Intent {
    val intent = Intent(context, IncomingCallActivity::class.java)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    intent.putExtra(EXTRA_CALL_ID, callId)
    intent.putExtra(EXTRA_CALL_TYPE, callType)
    intent.putExtra(EXTRA_CALL_INITIATOR_ID, callInitiatorId)
    intent.putExtra(EXTRA_CALL_INITIATOR_NAME, callInitiatorName)
    intent.putIntegerArrayListExtra(EXTRA_CALL_OPPONENTS, opponents)
    intent.putExtra(EXTRA_CALL_PHOTO, callPhoto)
    intent.putExtra(EXTRA_CALL_USER_INFO, userInfo)
    intent.putExtra(EXTRA_CUSTOM_BODY_TEXT, customBodyText)
    return intent
}


class IncomingCallActivity : Activity() {
    companion object {
        private const val TAG = "IncomingCallActivity"
    }

    private lateinit var callStateReceiver: BroadcastReceiver
    private lateinit var localBroadcastManager: LocalBroadcastManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var finishRunnable: Runnable? = null

    private var callId: String? = null
    private var callType = -1
    private var callInitiatorId = -1
    private var callInitiatorName: String? = null
    private var callOpponents: ArrayList<Int>? = ArrayList()
    private var callPhoto: String? = null
    private var callUserInfo: String? = null
    private var backgroundColor: String? = null
    private var customBodyText: String? = null


    override fun onCreate(@Nullable savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Diagnostic logging for lock screen state
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        Log.d(TAG, "=== IncomingCallActivity onCreate ===")
        Log.d(TAG, "Android Version: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "Is Keyguard Locked: ${keyguardManager.isKeyguardLocked}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Log.d(TAG, "Is Keyguard Secure: ${keyguardManager.isKeyguardSecure}")
            Log.d(TAG, "Is Device Locked: ${keyguardManager.isDeviceLocked}")
        }

        setContentView(resources.getIdentifier("activity_incoming_call", "layout", packageName))

        // Enhanced window flags for Android 12+ lock screen interaction
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)

            // CRITICAL for Android 12+: Enable touch interaction over lock screen
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
                Log.d(TAG, "Added FLAG_DISMISS_KEYGUARD for Android 12+")
            }
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // Keep screen on and allow lock while screen is on
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )

        Log.d(TAG, "Window flags set successfully")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            setInheritShowWhenLocked(true)
        }

        // Enhanced KeyguardManager integration with fallback for Android 12+
        with(keyguardManager) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "Attempting keyguard dismiss...")

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+: Enhanced handling with touch interaction fallback
                    requestDismissKeyguard(this@IncomingCallActivity, object :
                        KeyguardManager.KeyguardDismissCallback() {
                        override fun onDismissSucceeded() {
                            super.onDismissSucceeded()
                            Log.d(TAG, "Keyguard dismissed successfully")
                        }

                        override fun onDismissError() {
                            super.onDismissError()
                            Log.e(TAG, "Failed to dismiss keyguard - device may have secure lock")
                            // Fallback: Enable touch interaction anyway
                            enableTouchInteractionOverLockScreen()
                        }

                        override fun onDismissCancelled() {
                            super.onDismissCancelled()
                            Log.w(TAG, "Keyguard dismiss cancelled by user")
                            // Fallback: Enable touch interaction anyway
                            enableTouchInteractionOverLockScreen()
                        }
                    })
                } else {
                    // Android 8-11: Standard handling
                    requestDismissKeyguard(this@IncomingCallActivity, object :
                        KeyguardManager.KeyguardDismissCallback() {
                        override fun onDismissError() {
                            Log.d(TAG, "[KeyguardDismissCallback.onDismissError]")
                        }

                        override fun onDismissSucceeded() {
                            Log.d(TAG, "[KeyguardDismissCallback.onDismissSucceeded]")
                        }

                        override fun onDismissCancelled() {
                            Log.d(TAG, "[KeyguardDismissCallback.onDismissCancelled]")
                        }
                    })
                }
            } else {
                // Pre-Android 8: Use deprecated but functional method
                @Suppress("DEPRECATION")
                if (isKeyguardLocked) {
                    val keyguardLock = newKeyguardLock(Context.KEYGUARD_SERVICE)
                    keyguardLock?.disableKeyguard()
                    Log.d(TAG, "Used deprecated keyguard lock method for pre-Android 8")
                }
            }
        }

        processIncomingData(intent)
        initUi()
        initCallStateReceiver()
        registerCallStateReceiver()

        Log.d(TAG, "IncomingCallActivity initialization complete for call: $callId")
    }

    /**
     * Enables touch interaction over lock screen for Android 12+
     * Called as fallback when keyguard dismiss fails or is cancelled
     */
    private fun enableTouchInteractionOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )

                // Ensure window can receive touch events
                window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
                window.clearFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)

                Log.d(TAG, "Enabled touch interaction over lock screen as fallback")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enable touch interaction over lock screen", e)
            }
        }
    }

    private fun initCallStateReceiver() {
        localBroadcastManager = LocalBroadcastManager.getInstance(this)
        callStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null || TextUtils.isEmpty(intent.action)) return
                val action: String? = intent.action

                val callIdToProcess: String? = intent.getStringExtra(EXTRA_CALL_ID)
                if (TextUtils.isEmpty(callIdToProcess) || callIdToProcess != callId) {
                    return
                }
                when (action) {
                    ACTION_CALL_NOTIFICATION_CANCELED, ACTION_CALL_REJECT, ACTION_CALL_ENDED -> {
                        Log.d(TAG, "[BroadcastReceiver] Received call end signal: $action for call: $callIdToProcess")
                        finishAndRemoveTask()
                    }

                    ACTION_CALL_ACCEPT -> {
                        Log.d(TAG, "[BroadcastReceiver] Received call accept signal for call: $callIdToProcess")
                        finishDelayed()
                    }
                }
            }
        }
    }

    private fun finishDelayed() {
        // Cancel any existing delayed finish to prevent memory leaks
        finishRunnable?.let { mainHandler.removeCallbacks(it) }

        finishRunnable = Runnable {
            if (!isFinishing) {
                finishAndRemoveTask()
            }
        }
        mainHandler.postDelayed(finishRunnable!!, 1000)
    }

    private fun registerCallStateReceiver() {
        val intentFilter = IntentFilter()
        intentFilter.addAction(ACTION_CALL_NOTIFICATION_CANCELED)
        intentFilter.addAction(ACTION_CALL_REJECT)
        intentFilter.addAction(ACTION_CALL_ACCEPT)
        intentFilter.addAction(ACTION_CALL_ENDED)
        localBroadcastManager.registerReceiver(callStateReceiver, intentFilter)
    }

    private fun unRegisterCallStateReceiver() {
        localBroadcastManager.unregisterReceiver(callStateReceiver)
    }

    override fun onDestroy() {
        super.onDestroy()

        // Cancel any pending delayed finish to prevent memory leaks
        finishRunnable?.let { mainHandler.removeCallbacks(it) }
        finishRunnable = null

        unRegisterCallStateReceiver()
        Log.d(TAG, "[onDestroy] Incoming call activity destroyed for call: $callId")
    }

    override fun finishAndRemoveTask() {
        Log.d(TAG, "[finishAndRemoveTask] Closing incoming call activity for call: $callId")
        super.finishAndRemoveTask()
    }

    private fun processIncomingData(intent: Intent) {
        callId = intent.getStringExtra(EXTRA_CALL_ID)
        callType = intent.getIntExtra(EXTRA_CALL_TYPE, -1)
        callInitiatorId = intent.getIntExtra(EXTRA_CALL_INITIATOR_ID, -1)
        callInitiatorName = intent.getStringExtra(EXTRA_CALL_INITIATOR_NAME)
        callOpponents = intent.getIntegerArrayListExtra(EXTRA_CALL_OPPONENTS)
        callPhoto = intent.getStringExtra(EXTRA_CALL_PHOTO)
        callUserInfo = intent.getStringExtra(EXTRA_CALL_USER_INFO)
        backgroundColor = intent.getStringExtra(EXTRA_BACKGROUND_COLOR)
        customBodyText = intent.getStringExtra(EXTRA_CUSTOM_BODY_TEXT)
    }

    private fun initUi() {
        // Apply dynamic background color
        val mainBackground = findViewById<RelativeLayout>(resources.getIdentifier("main_background", "id", packageName))
        if (!TextUtils.isEmpty(backgroundColor)) {
            try {
                val color = Color.parseColor(backgroundColor)
                mainBackground.setBackgroundColor(color)
            } catch (e: Exception) {
                Log.w(TAG, "Invalid background color: $backgroundColor", e)
                // Keep default color if parsing fails
            }
        }

        // Set caller name
        val callTitleTxt: TextView =
            findViewById(resources.getIdentifier("user_name_txt", "id", packageName))
        callTitleTxt.text = callInitiatorName

        // Handle custom message display
        val messageContainer = findViewById<LinearLayout>(resources.getIdentifier("message_container", "id", packageName))
        val customMessageTxt = findViewById<TextView>(resources.getIdentifier("custom_message_txt", "id", packageName))
        val messageLabelTxt = findViewById<TextView>(resources.getIdentifier("message_label_txt", "id", packageName))
        
        if (!TextUtils.isEmpty(customBodyText)) {
            messageContainer.visibility = View.VISIBLE
            messageLabelTxt.visibility = View.VISIBLE
            customMessageTxt.text = customBodyText
        } else {
            messageContainer.visibility = View.GONE
            messageLabelTxt.visibility = View.GONE
        }

        val avatarImg: ShapeableImageView =
            findViewById(resources.getIdentifier("avatar_img", "id", packageName))

        val defaultPhotoResId = getPhotoPlaceholderResId(applicationContext)

        if (!TextUtils.isEmpty(callPhoto)) {
            val imageSize = com.connectycube.flutter.connectycube_flutter_call_kit.utils.getMaxImageSize(applicationContext)
            val cachingEnabled = com.connectycube.flutter.connectycube_flutter_call_kit.utils.getImageCachingEnabled(applicationContext)
            val timeout = com.connectycube.flutter.connectycube_flutter_call_kit.utils.getImageLoadingTimeout(applicationContext)
            
            val glideRequest = Glide.with(applicationContext)
                .load(callPhoto)
                .override(imageSize, imageSize) // Use configurable image size
                .timeout(timeout) // Use configurable timeout
                .error(defaultPhotoResId)
                .placeholder(defaultPhotoResId)
                
            // Apply caching strategy based on configuration
            val finalRequest = if (cachingEnabled) {
                glideRequest.diskCacheStrategy(com.bumptech.glide.load.engine.DiskCacheStrategy.ALL)
            } else {
                glideRequest.diskCacheStrategy(com.bumptech.glide.load.engine.DiskCacheStrategy.NONE)
            }
            
            finalRequest
                .listener(object : com.bumptech.glide.request.RequestListener<android.graphics.drawable.Drawable> {
                    override fun onLoadFailed(
                        e: com.bumptech.glide.load.engine.GlideException?,
                        model: Any?,
                        target: com.bumptech.glide.request.target.Target<android.graphics.drawable.Drawable>?,
                        isFirstResource: Boolean
                    ): Boolean {
                        Log.w(TAG, "Failed to load caller image: $callPhoto", e)
                        return false // Let Glide handle the error with error drawable
                    }

                    override fun onResourceReady(
                        resource: android.graphics.drawable.Drawable?,
                        model: Any?,
                        target: com.bumptech.glide.request.target.Target<android.graphics.drawable.Drawable>?,
                        dataSource: com.bumptech.glide.load.DataSource?,
                        isFirstResource: Boolean
                    ): Boolean {
                        Log.d(TAG, "Successfully loaded caller image: $callPhoto")
                        return false // Let Glide display the image
                    }
                })
                .into(avatarImg)
        } else {
            avatarImg.setImageResource(defaultPhotoResId)
        }
        
        // Setup slide to answer button
        val slideToAnswerBtn = findViewById<SlideToAnswerView>(resources.getIdentifier("slide_to_answer_btn", "id", packageName))
        slideToAnswerBtn.setOnSlideCompleteListener {
            onStartCall(null)
        }
    }

    // calls from layout file
    fun onEndCall(view: View?) {
        val bundle = Bundle()
        bundle.putString(EXTRA_CALL_ID, callId)
        bundle.putInt(EXTRA_CALL_TYPE, callType)
        bundle.putInt(EXTRA_CALL_INITIATOR_ID, callInitiatorId)
        bundle.putString(EXTRA_CALL_INITIATOR_NAME, callInitiatorName)
        bundle.putIntegerArrayList(EXTRA_CALL_OPPONENTS, callOpponents)
        bundle.putString(EXTRA_CALL_PHOTO, callPhoto)
        bundle.putString(EXTRA_CALL_USER_INFO, callUserInfo)
        bundle.putString(EXTRA_BACKGROUND_COLOR, backgroundColor)
        bundle.putString(EXTRA_CUSTOM_BODY_TEXT, customBodyText)

        val endCallIntent = Intent(this, EventReceiver::class.java)
        endCallIntent.action = ACTION_CALL_REJECT
        endCallIntent.putExtras(bundle)
        applicationContext.sendBroadcast(endCallIntent)
    }

    // calls from layout file
    fun onStartCall(view: View?) {
        val bundle = Bundle()
        bundle.putString(EXTRA_CALL_ID, callId)
        bundle.putInt(EXTRA_CALL_TYPE, callType)
        bundle.putInt(EXTRA_CALL_INITIATOR_ID, callInitiatorId)
        bundle.putString(EXTRA_CALL_INITIATOR_NAME, callInitiatorName)
        bundle.putIntegerArrayList(EXTRA_CALL_OPPONENTS, callOpponents)
        bundle.putString(EXTRA_CALL_PHOTO, callPhoto)
        bundle.putString(EXTRA_CALL_USER_INFO, callUserInfo)
        bundle.putString(EXTRA_BACKGROUND_COLOR, backgroundColor)
        bundle.putString(EXTRA_CUSTOM_BODY_TEXT, customBodyText)

        // Ensure caller information is persisted in call data before accepting
        persistCallerInformation()

        val startCallIntent = Intent(this, EventReceiver::class.java)
        startCallIntent.action = ACTION_CALL_ACCEPT
        startCallIntent.putExtras(bundle)
        applicationContext.sendBroadcast(startCallIntent)
    }

    private fun persistCallerInformation() {
        // Save caller information to ensure it's available throughout the call
        if (callId != null && callInitiatorName != null) {
            try {
                val callerData = mapOf(
                    "session_id" to callId,
                    "caller_name" to callInitiatorName,
                    "caller_id" to callInitiatorId.toString(),
                    "call_type" to callType.toString(),
                    "call_photo" to (callPhoto ?: ""),
                    "background_color" to (backgroundColor ?: ""),
                    "custom_body_text" to (customBodyText ?: "")
                )
                
                // Store in SharedPreferences for persistence across activities
                val prefs = getSharedPreferences("connectycube_call_data", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                callerData.forEach { (key, value) ->
                    editor.putString("${callId}_${key}", value)
                }
                editor.apply()

                Log.d(TAG, "Persisted caller information for call: $callId, caller: $callInitiatorName")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to persist caller information", e)
            }
        }
    }

}
