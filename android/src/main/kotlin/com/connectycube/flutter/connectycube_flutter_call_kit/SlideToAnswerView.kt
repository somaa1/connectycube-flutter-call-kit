package com.connectycube.flutter.connectycube_flutter_call_kit

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import androidx.core.content.ContextCompat
import kotlin.math.max
import kotlin.math.min

class SlideToAnswerView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var onSlideCompleteListener: (() -> Unit)? = null
    
    // Animation and state variables
    private var slidePosition = 0f
    private var isDragging = false
    private var startX = 0f
    private var currentAnimator: ValueAnimator? = null
    
    // Drawing objects
    private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val thumbPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val arrowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    
    // Dimensions
    private var thumbRadius = 0f
    private var maxSlideDistance = 0f
    private var slideThreshold = 0.7f // 70% slide to trigger
    
    // Colors
    private var backgroundColor = Color.parseColor("#40FFFFFF")
    private var thumbColor = Color.parseColor("#80FFFFFF")
    private var textColor = Color.WHITE
    private var arrowColor = Color.WHITE
    
    init {
        setupPaints()
        isClickable = true
        isFocusable = true
    }
    
    private fun setupPaints() {
        backgroundPaint.apply {
            style = Paint.Style.FILL
            color = backgroundColor
        }
        
        thumbPaint.apply {
            style = Paint.Style.FILL
            color = thumbColor
            setShadowLayer(8f, 0f, 4f, Color.parseColor("#20000000"))
        }
        
        textPaint.apply {
            color = textColor
            textSize = 16f * resources.displayMetrics.density
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        
        arrowPaint.apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f * resources.displayMetrics.density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            color = arrowColor
        }
        
        setLayerType(LAYER_TYPE_SOFTWARE, null)
    }
    
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = (56 * resources.displayMetrics.density).toInt() // 56dp height
        
        thumbRadius = (height * 0.35f)
        maxSlideDistance = width - (thumbRadius * 2) - (16 * resources.displayMetrics.density)
        
        setMeasuredDimension(width, height)
    }
    
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        
        val centerY = height / 2f
        val cornerRadius = height / 2f
        
        // Draw background track
        val backgroundRect = RectF(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(backgroundRect, cornerRadius, cornerRadius, backgroundPaint)
        
        // Calculate thumb position
        val thumbCenterX = thumbRadius + (16 * resources.displayMetrics.density) + slidePosition
        
        // Draw text with fade effect based on slide position
        val textAlpha = (255 * (1f - slidePosition / maxSlideDistance * 0.8f)).toInt()
        textPaint.alpha = max(50, textAlpha)
        
        val textY = centerY + (textPaint.textSize / 3)
        canvas.drawText("Slide to answer", width / 2f, textY, textPaint)
        
        // Draw sliding thumb
        thumbPaint.alpha = if (isDragging) 200 else 180
        canvas.drawCircle(thumbCenterX, centerY, thumbRadius, thumbPaint)
        
        // Draw arrow in thumb
        drawArrow(canvas, thumbCenterX, centerY, thumbRadius * 0.4f)
    }
    
    private fun drawArrow(canvas: Canvas, centerX: Float, centerY: Float, size: Float) {
        val arrowPath = Path()
        
        // Arrow pointing right
        arrowPath.moveTo(centerX - size * 0.3f, centerY - size * 0.5f)
        arrowPath.lineTo(centerX + size * 0.3f, centerY)
        arrowPath.lineTo(centerX - size * 0.3f, centerY + size * 0.5f)
        
        arrowPaint.alpha = if (isDragging) 255 else 200
        canvas.drawPath(arrowPath, arrowPaint)
    }
    
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                startX = event.x
                val thumbCenterX = thumbRadius + (16 * resources.displayMetrics.density) + slidePosition
                
                // Check if touch is within thumb area
                if (kotlin.math.abs(event.x - thumbCenterX) <= thumbRadius * 1.5f) {
                    isDragging = true
                    currentAnimator?.cancel()
                    invalidate()
                    return true
                }
            }
            
            MotionEvent.ACTION_MOVE -> {
                if (isDragging) {
                    val deltaX = event.x - startX
                    slidePosition = max(0f, min(maxSlideDistance, slidePosition + deltaX))
                    startX = event.x
                    invalidate()
                    
                    // Haptic feedback when near completion
                    if (slidePosition > maxSlideDistance * slideThreshold && slidePosition < maxSlideDistance * (slideThreshold + 0.1f)) {
                        performHapticFeedback(HAPTIC_FEEDBACK_LIGHT_IMPACT)
                    }
                    
                    return true
                }
            }
            
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (isDragging) {
                    isDragging = false
                    
                    // Check if slide is complete
                    if (slidePosition >= maxSlideDistance * slideThreshold) {
                        // Slide to completion and trigger callback
                        animateToPosition(maxSlideDistance) {
                            onSlideCompleteListener?.invoke()
                        }
                    } else {
                        // Snap back to start
                        animateToPosition(0f)
                    }
                    
                    invalidate()
                    return true
                }
            }
        }
        
        return super.onTouchEvent(event)
    }
    
    private fun animateToPosition(targetPosition: Float, onComplete: (() -> Unit)? = null) {
        currentAnimator?.cancel()
        
        currentAnimator = ValueAnimator.ofFloat(slidePosition, targetPosition).apply {
            duration = 200
            interpolator = DecelerateInterpolator()
            
            addUpdateListener { animator ->
                slidePosition = animator.animatedValue as Float
                invalidate()
            }
            
            doOnEnd {
                onComplete?.invoke()
            }
            
            start()
        }
    }
    
    fun setOnSlideCompleteListener(listener: () -> Unit) {
        onSlideCompleteListener = listener
    }
    
    fun reset() {
        currentAnimator?.cancel()
        slidePosition = 0f
        isDragging = false
        invalidate()
    }
    
    // Extension function for animation completion
    private fun ValueAnimator.doOnEnd(action: () -> Unit) {
        addListener(object : android.animation.Animator.AnimatorListener {
            override fun onAnimationEnd(animation: android.animation.Animator) = action()
            override fun onAnimationStart(animation: android.animation.Animator) {}
            override fun onAnimationCancel(animation: android.animation.Animator) {}
            override fun onAnimationRepeat(animation: android.animation.Animator) {}
        })
    }
}