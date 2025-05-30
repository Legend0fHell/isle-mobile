package com.uet.isle

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.ImageDecoder
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Base64
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.errorprone.annotations.FormatString
import java.io.File
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.locks.ReentrantLock
import java.nio.ByteBuffer
import kotlin.concurrent.withLock
import org.json.JSONArray
import org.json.JSONObject

class HandLandmarkDetector(
    private val context: Context,
    val handLandmarkerHelperListener: LandmarkerListener? = null
) {
    private val TAG = "HandLandmarkDetector"
    
    private var handLandmarker: HandLandmarker? = null
    private var modelFile: File? = null
    private var isUsingGPU = false
    
    init {
        setupModel()
    }

    fun setupModel() {
        // Get the model file from assets
        val assetManager = context.assets
        val modelPath = "flutter_assets/assets/models/hand_landmarker.task"
        
        try {
            Log.i(TAG, "Setting up hand landmark model from: $modelPath")
            
            // Copy the model file to a temporary location
            assetManager.open(modelPath).use { inputStream ->
                val tempFile = File(context.cacheDir, "hand_landmarker.task")
                tempFile.outputStream().use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                
                modelFile = tempFile
                
                // Try GPU first, fallback to CPU if not available
                val delegate = try {
                    Delegate.GPU
                } catch (e: Exception) {
                    Delegate.CPU
                }
                
                isUsingGPU = delegate == Delegate.GPU
                
                // Setup HandLandmarker
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath(tempFile.absolutePath)
                    .setDelegate(delegate)
                    .build()
                
                val handLandmarkerOptions = HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setNumHands(1)  
                    .setMinHandDetectionConfidence(0.5f)
                    .setMinHandPresenceConfidence(0.5f)
                    .setResultListener(this::returnOnResult)
                    .setErrorListener(this::returnOnError)
                    .build()
                
                handLandmarker = HandLandmarker.createFromOptions(context, handLandmarkerOptions)
                Log.i(TAG, "HandLandmarker successfully initialized")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up hand landmark model", e)
        }
    }
    
    fun detectLandmarks(imageBytes: ByteArray): String {
        if (handLandmarker == null) {
            Log.e(TAG, "HandLandmarker not initialized")
            return "fail"
        }
        
        var bitmap: Bitmap?
        
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)

        // Create MPImage from the processed bitmap
        val mpImage = BitmapImageBuilder(bitmap).build()

        detectAsync(mpImage, SystemClock.uptimeMillis())

        return "success"
    }

    private fun detectAsync(mpImage: MPImage, frameTime: Long) {
        handLandmarker?.detectAsync(mpImage, frameTime)
    }
    
    private fun convertResultToJson(result: HandLandmarkerResult?, inferenceTime: Long, height: Int, width: Int): String {
        val json = JSONObject()
        
        json.put("delegate", if (isUsingGPU) "GPU" else "CPU")
        json.put("inferenceTime", inferenceTime)
        json.put("height", height)
        json.put("width", width)

        try {
            if (result == null || result.landmarks().isEmpty()) {
                json.put("landmarks", JSONArray())
                return json.toString()
            }
            
            val landmarks = JSONArray()
            
            // For simplicity, we'll just take the first hand
            val handLandmarkList = result.landmarks()[0]
            val isLeftHand = result.handednesses()[0][0].categoryName() == "Left"
            
            for (i in 0 until handLandmarkList.size) {
                val landmarkJson = JSONObject()
                
                // Get the landmark coordinates (normalized to [0,1])
                val landmark: NormalizedLandmark = handLandmarkList[i]
                
                landmarkJson.put("index", i)
                landmarkJson.put("x", landmark.x())
                landmarkJson.put("y", landmark.y())
                landmarkJson.put("z", landmark.z())
                
                landmarks.put(landmarkJson)
            }
            
            json.put("landmarks", landmarks)
            json.put("isLeftHand", isLeftHand)
            
            // Log successful detection
            // Log.d(TAG, "[NativeAndr] Successful: ${handLandmarkList.size} landmarks, inf: $inferenceTime ms")
        } catch (e: Exception) {
            // If any error occurs during parsing, return an empty result
            Log.e(TAG, "Error parsing landmarks: ${e.message}")
            json.put("landmarks", JSONArray())
            json.put("error", e.message)
        }
        
        return json.toString()
    }
    
    private fun returnOnResult(result: HandLandmarkerResult, inputImg: MPImage) {
        val finishTimeMs = SystemClock.uptimeMillis()
        val inferenceTime = finishTimeMs - result.timestampMs()
        val height = inputImg.height
        val width = inputImg.width
        val jsonResult = convertResultToJson(result, inferenceTime, height, width)
        handLandmarkerHelperListener?.onResults(jsonResult)
    }

    private fun returnOnError(error: Exception) {
        handLandmarkerHelperListener?.onError(error.message ?: "Unknown error")
    }

    interface LandmarkerListener {
        fun onError(error: String)
        fun onResults(jsonResult: String)
    }

    fun close() {
        handLandmarker?.close()
        handLandmarker = null
    }
} 