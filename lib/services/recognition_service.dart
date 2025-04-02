import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
  final _throttler = Throttler(duration: const Duration(milliseconds: 100));

  static const String modelFilename = 'asl_landmark_model.tflite';
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

  Future<File> getFile(String fileName) async {
    final appDir = await getApplicationSupportDirectory();
    final appPath = appDir.path;
    final fileOnDevice = File('$appPath/$modelFilename');
    AppLogger.info('TFLite On device File path: $appPath/$modelFilename');
    final rawAssetFile = await rootBundle.load(fileName);
    // check if rawAssetFile is empty
    if (rawAssetFile.lengthInBytes == 0) {
      AppLogger.error('Error: rawAssetFile is empty');
      throw Exception('Error: rawAssetFile is empty');
    }
    final rawBytes = rawAssetFile.buffer.asUint8List();
    await fileOnDevice.writeAsBytes(rawBytes, flush: true);
    return fileOnDevice;
  }

  // Separate method for async initialization
  Future<void> _initializeAsync() async {
    // Get the model file
    try {
      final modelPath = 'assets/models/$modelFilename';
      final modelFile = await getFile(modelPath);

      // Create interpreter options
      final interpreterOptions = InterpreterOptions()..threads = 4;

      // Load interpreter in a non-blocking way
      _interpreter = Interpreter.fromFile(
        modelFile,
        options: interpreterOptions,
      );
      AppLogger.info('Successfully loaded TFLite model from: $modelPath');

      _isInitialized = true;
    } catch (e) {
      AppLogger.error('Error preparing TFLite model: $e');
      return;
    }
  }

  Future<RecognitionResult?> processHandLandmarks(featuresObj) async {
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
        // Use TFLite model in a separate isolate
        final input = _preprocessFeatures(featuresObj);
        final outputList = List<double>.filled(numOutputs, 0.0);
        AppLogger.info('Stage2 Input: $input');

        // Run inference in isolate to avoid blocking the UI
        final result = await compute(
          _runInferenceInIsolate,
          _InferenceParams(input, outputList, _interpreter!),
        );
        final output = _processOutput(result);
        AppLogger.info('Stage2 Output: $output.toString()');
        return output;
      } catch (e) {
        AppLogger.error('Error processing hand landmarks (phase 2)', e);
        return null;
      }
    });
  }

  List<List<double>> _preprocessFeatures(featuresObj) {
    // featuresObj is a json object, there exists an array called 'landmarks', consisting of 21 objects, each with index, x, y
    // Convert landmarks to a flat list of doubles, first 21 items are x, next 21 are y

    // first extract the array landmarks out of featuresObj
    final landmarks = featuresObj['landmarks'] as List<dynamic>;

    // Flatten the landmarks into a single list
    final featuresModel = List<double>.filled(
      numLandmarks * coordsPerLandmark,
      0.0,
    );
    // featuresModel, first 21 items are x (landmark_0_x, landmark_1_x, ...), next 21 are y (landmark_0_y, landmark_1_y, ...)
    for (int i = 0; i < numLandmarks; i++) {
      featuresModel[i] = landmarks[i]['x'] as double;
    }
    for (int i = 0; i < numLandmarks; i++) {
      featuresModel[numLandmarks + i] = landmarks[i]['y'] as double;
    }

    return [featuresModel];
  }

  RecognitionResult _processOutput(List<double> output) {
    // Find the index of the highest confidence value
    AppLogger.info('Stage2 Output: $output');
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
