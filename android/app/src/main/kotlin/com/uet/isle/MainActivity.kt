package com.uet.isle

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.res.AssetManager
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.uet.isle/hand_landmark"
    private var handLandmarkDetector: HandLandmarkDetector? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize the detector
        val listener = object : HandLandmarkDetector.LandmarkerListener {
            override fun onResults(jsonResult: String) {
                // Send the results back to Flutter
                // Log.i("HandLandmarkDetector", "Results: $jsonResult")
                runOnUiThread {
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onLandmarksDetected", jsonResult)
                }
            }

            override fun onError(error: String) {
                // Handle errors if needed
                Log.e("HandLandmarkDetector", "Error: $error")
            }
        }

        handLandmarkDetector = HandLandmarkDetector(context, listener)
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectLandmarks" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")

                    if (handLandmarkDetector == null) {
                        result.error("DETECTOR_NOT_INITIALIZED", "Hand landmark detector not initialized", null)
                    }
                    result.success(handLandmarkDetector?.detectLandmarks(imageBytes!!))
                }
                "prepareAssetFile" -> {
                    val assetPath = call.argument<String>("assetPath")
                    val fileName = call.argument<String>("fileName")
                    
                    if (assetPath != null && fileName != null) {
                        val outputFile = prepareAssetFile(assetPath, fileName)
                        result.success(outputFile.absolutePath)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Asset path or file name not provided", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun prepareAssetFile(assetPath: String, fileName: String): File {
        val assetManager = context.assets
        
        try {
            // Log the asset path for debugging
            val alternativePath = "flutter_assets/$assetPath"
            println("Trying path: $alternativePath")

            val inputStream = assetManager.open(alternativePath)
            val outputFile = File(context.filesDir, fileName)
            
            FileOutputStream(outputFile).use { output ->
                inputStream.copyTo(output)
            }
            
            println("Successfully copied asset to: ${outputFile.absolutePath}")
            return outputFile
        } catch (e: Exception) {
            // Log the error and try an alternative path
            println("Error loading asset: ${e.message}")
            throw e
        }
    }

    override fun onDestroy() {
        handLandmarkDetector?.close()
        handLandmarkDetector = null
        super.onDestroy()
    }
} 