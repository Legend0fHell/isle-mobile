package com.uet.isle

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import org.json.JSONObject
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.uet.isle/hand_landmark"
    private var handLandmarkDetector: HandLandmarkDetector? = null
    private var isEmulatorMode = false
    private val TAG = "MainActivity"
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize method channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Set up method channel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "detectLandmarks" -> handleDetectLandmarks(call, result)
                "prepareAssetFile" -> handlePrepareAssetFile(call, result)
                "setEmulatorMode" -> handleSetEmulatorMode(call, result)
                else -> result.notImplemented()
            }
        }
    }
    
    private fun handleDetectLandmarks(call: MethodCall, result: MethodChannel.Result) {
        // In emulator mode, return success immediately and let Flutter handle mock data
        if (isEmulatorMode) {
            result.success("success")
            return
        }
        
        try {
            val imageBytes = call.argument<ByteArray>("imageBytes")
            if (imageBytes == null) {
                result.error("INVALID_ARGUMENT", "Image bytes not provided", null)
                return
            }
            
            // Lazy initialization
            if (handLandmarkDetector == null) {
                setupDetector()
            }
            
            // If initialization failed, report error
            if (handLandmarkDetector == null) {
                result.error("DETECTOR_NOT_INITIALIZED", "Hand landmark detector not initialized", null)
                return
            }
            
            // Process the image
            result.success(handLandmarkDetector?.detectLandmarks(imageBytes))
        } catch (e: Exception) {
            Log.e(TAG, "Error processing image: ${e.message}")
            result.error("PROCESSING_ERROR", e.message, null)
        }
    }
    
    private fun handlePrepareAssetFile(call: MethodCall, result: MethodChannel.Result) {
        // Skip file preparation in emulator mode
        if (isEmulatorMode) {
            result.success("emulator_mode")
            return
        }
        
        try {
            val assetPath = call.argument<String>("assetPath")
            val fileName = call.argument<String>("fileName")
            
            if (assetPath == null || fileName == null) {
                result.error("INVALID_ARGUMENTS", "Asset path or file name not provided", null)
                return
            }
            
            val outputFile = prepareAssetFile(assetPath, fileName)
            result.success(outputFile.absolutePath)
        } catch (e: Exception) {
            Log.e(TAG, "Error preparing asset file: ${e.message}")
            result.error("ASSET_PREPARATION_ERROR", e.message, null)
        }
    }
    
    private fun handleSetEmulatorMode(call: MethodCall, result: MethodChannel.Result) {
        val newEmulatorMode = call.argument<Boolean>("enabled") ?: false
        
        // If turning off emulator mode and we had a detector, clean it up
        if (isEmulatorMode && !newEmulatorMode) {
            cleanupDetector()
        }
        
        // Update mode
        isEmulatorMode = newEmulatorMode
        Log.i(TAG, "EMU_SUPPORT mode set to: $isEmulatorMode")
        
        result.success(isEmulatorMode)
    }
    
    private fun setupDetector() {
        try {
            Log.i(TAG, "Setting up HandLandmarkDetector...")
            
            // Create the detector listener
            val listener = object : HandLandmarkDetector.LandmarkerListener {
                override fun onResults(jsonResult: String) {
                    runOnUiThread {
                        try {
                            methodChannel.invokeMethod("onLandmarksDetected", jsonResult)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending results to Flutter: ${e.message}")
                        }
                    }
                }

                override fun onError(error: String) {
                    Log.e(TAG, "Detector error: $error")
                }
            }
            
            // Create the detector
            handLandmarkDetector = HandLandmarkDetector(applicationContext, listener)
            Log.i(TAG, "HandLandmarkDetector initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing HandLandmarkDetector: ${e.message}")
            cleanupDetector()
        }
    }
    
    private fun cleanupDetector() {
        try {
            handLandmarkDetector?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing detector: ${e.message}")
        } finally {
            handLandmarkDetector = null
        }
    }
    
    private fun prepareAssetFile(assetPath: String, fileName: String): File {
        val assetManager = context.assets
        val alternativePath = "flutter_assets/$assetPath"
        
        Log.i(TAG, "Preparing asset: $alternativePath")
        val inputStream = assetManager.open(alternativePath)
        val outputFile = File(context.filesDir, fileName)
        
        FileOutputStream(outputFile).use { output ->
            inputStream.copyTo(output)
        }
        
        Log.i(TAG, "Asset prepared at: ${outputFile.absolutePath}")
        return outputFile
    }

    override fun onDestroy() {
        cleanupDetector()
        super.onDestroy()
    }
} 