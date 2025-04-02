import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../models/recognition_model.dart';
import '../utils/logger.dart';

// Helper class for running inference in isolate
class _InferenceParams {
  final List<List<double>> input;
  final List<double> outputShape;
  final Interpreter interpreter;

  _InferenceParams(this.input, this.outputShape, this.interpreter);
}

// Function to run in separate isolate
Future<List<double>> _runInferenceInIsolate(_InferenceParams params) async {
  final output = List<List<double>>.filled(
    1,
    List<double>.filled(params.outputShape.length, 0.0),
  );
  params.interpreter.run(params.input, output);
  return output[0];
}

class RecognitionService {
  static const int numLandmarks = 21; // MediaPipe provides 21 hand landmarks
  static const int coordsPerLandmark = 2; // Each landmark has x, y coordinates
  static const int numOutputs = 28; // 26 letters + space + delete
  static const List<String> outputs = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'space',
    'delete',
  ];

  Interpreter? _interpreter;
  bool _isInitialized = false;
  final _throttler = Throttler(duration: const Duration(milliseconds: 250));

  // Initialize in background
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the TFLite model asynchronously
      await _initializeAsync();
    } catch (e) {
      AppLogger.error('Error initializing SignLanguageRecognitionService', e);
      _isInitialized = true;
    }
  }

  // Separate method for async initialization
  Future<void> _initializeAsync() async {
    // Use compute for heavy file operations
    final modelPath = await compute(
      _getModelPathIsolate,
      "asl_landmark_model.tflite",
    );
    final modelFile = File(modelPath);

    if (await modelFile.exists()) {
      // Create interpreter options
      final interpreterOptions = InterpreterOptions()..threads = 4;

      // Load interpreter in a non-blocking way
      _interpreter = Interpreter.fromFile(
        modelFile,
        options: interpreterOptions,
      );
      AppLogger.info('Successfully loaded TFLite model from: $modelPath');
    } else {
      AppLogger.error('Sign language model file not found at: $modelPath');
    }

    _isInitialized = true;
  }

  // Static method to get model path in isolate
  static Future<String> _getModelPathIsolate(String modelName) async {
    final appDir = await getApplicationDocumentsDirectory();
    return join(appDir.path, modelName);
  }

  Future<RecognitionResult?> processHandLandmarks(landmarks) async {
    // Start initialization if needed, but don't wait for it to complete
    if (!_isInitialized) {
      unawaited(initialize());
      return null;
    }

    return _throttler.throttle(() async {
      try {
        if (_interpreter == null) {
          AppLogger.error('TFLite interpreter not initialized');
          return null;
        }

        // Use the real TFLite model in a separate isolate
        final input = _preprocessLandmarks(landmarks);
        final outputList = List<double>.filled(numOutputs, 0.0);

        // Run inference in isolate to avoid blocking the UI
        final result = await compute(
          _runInferenceInIsolate,
          _InferenceParams(input, outputList, _interpreter!),
        );

        return _processOutput(result);
      } catch (e) {
        AppLogger.error('Error processing hand landmarks (phase 2)', e);
        return null;
      }
    });
  }

  List<List<double>> _preprocessLandmarks(landmarks) {
    // Get the flat list of normalized landmark coordinates
    final flatLandmarks = landmarks.toFloatList();

    // MediaPipe hand landmarks are already normalized to [0,1]
    // For this example, we're assuming the model expects a 1x(numLandmarks*2) input
    // where each landmark has x, y coordinates
    return [flatLandmarks];
  }

  RecognitionResult _processOutput(List<double> output) {
    // Find the index of the highest confidence value
    double maxConfidence = 0.0;
    int maxIndex = 0;

    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }

    return RecognitionResult(
      character: outputs[maxIndex],
      confidence: maxConfidence,
      delegateType: 'CPU', // TODO: Update this if using GPU delegate
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

// A simple throttler to limit the frequency of recognition
class Throttler {
  final Duration duration;
  Timer? _timer;

  Throttler({required this.duration});

  Future<T> throttle<T>(Future<T> Function() callback) async {
    if (_timer?.isActive ?? false) {
      return Future.value(null as T);
    }

    _timer = Timer(duration, () {});
    return await callback();
  }
}
