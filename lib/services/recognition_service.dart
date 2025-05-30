import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/recognition_model.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  static const int coordsPerLandmark =
      3; // Each landmark has x, y, z coordinates
  static const int numOutputs = 29; // 26 letters + delete + space + autocmp
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
    'delete',
    'space',
    'autocmp',
  ];

  Interpreter? _interpreter;
  bool _isInitialized = false;
  final _throttler = Throttler(duration: const Duration(milliseconds: 250));
  bool _isMockStage2Enabled = false;

  static const String modelFilename = 'asl_landmark_model.tflite';
  // Initialize in background
  Future<void> initialize() async {
    // Check if we're in emulator mode (where MediaPipe isn't supported)
    _isMockStage2Enabled = dotenv.env['MOCK_STAGE2_OUTPUT'] == 'true' || kIsWeb;
    if (_isMockStage2Enabled) {
      AppLogger.info(
        'Recognition Service (Stage2) initializing in mock output -- all outputs are random!',
      );
      _isInitialized = true;
      return;
    }

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

    // If in emulator mode, generate mock results
    if (_isMockStage2Enabled) {
      return _generateMockResult();
    }
    
    // Verify landmarks contain data before processing
    final landmarksList = featuresObj['landmarks'] as List<dynamic>?;
    if (landmarksList == null || landmarksList.isEmpty) {
      // No valid landmarks, don't process
      AppLogger.warn("Empty landmarks list, skipping recognition");
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
        // AppLogger.info('Stage2 Input: $input');

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
    
    // Double-check landmarks list is not empty to prevent range errors
    if (landmarks.isEmpty) {
      AppLogger.error('Landmarks list is empty in preprocessFeatures');
      // Return a default input with zeros to prevent crashes
      return [List<double>.filled(numLandmarks * coordsPerLandmark, 0.0)];
    }

    // Flatten the landmarks into a single list
    final featuresModel = List<double>.filled(
      numLandmarks * coordsPerLandmark,
      0.0,
    );
    // featuresModel, first 21 items are x (landmark_0_x, landmark_1_x, ...), next 21 are y (landmark_0_y, landmark_1_y, ...)
    final List<double> meanFactor = [0.5266918922009487, 0.599997566719562, 0.6325379887318807, 0.6054403856079374, 0.5648815159641932, 0.569634151638943, 0.5602007738435635, 0.5548773826568293, 0.5499237921739559, 0.5105543305069834, 0.4980587470115053, 0.5071570100807082, 0.5142909398756957, 0.4608127166736475, 0.44888470675069275, 0.47686233081484813, 0.4985922443171651, 0.4188783629739356, 0.40889573095025544, 0.42683043213547905, 0.4410404423587047, 0.7233744983100655, 0.6686417956631482, 0.5854505408567676, 0.5221561960248686, 0.49052158201916446, 0.4648482217817647, 0.3898317794536519, 0.3804791844421446, 0.3732399933258757, 0.47206774675127, 0.4061604690683496, 0.42349843127890957, 0.43018561883131184, 0.4993266533003021, 0.453631407733774, 0.4967566709114261, 0.52270438244894, 0.5390989645887565, 0.5005901119552694, 0.5204309269779775, 0.533366685177312, 2.4723534285555108e-06, -0.050798926894795246, -0.07450163014561197, -0.09473899597177216, -0.11188970756051245, -0.04461367381220846, -0.09049221888938963, -0.12224202277505256, -0.14092758258231353, -0.04536658987668323, -0.09476129398321215, -0.11931337020447555, -0.12952884630970415, -0.052962503256004725, -0.10941214049574594, -0.11947343799390173, -0.11409088906651604, -0.06445357117303901, -0.10497737976655526, -0.10593909771020406, -0.0988678469402476];
    final List<double> stdFactor = [0.20811641053603724, 0.18888717223300605, 0.18514490695726835, 0.19487228488457467, 0.21365079148188543, 0.179214872974653, 0.1960729384982867, 0.21316192183869007, 0.2330019613808582, 0.16864758025326307, 0.17890851716016457, 0.1885940968077836, 0.20217068684877376, 0.16618664494623847, 0.17374159271861384, 0.1811100458903511, 0.188394444419778, 0.17353973726991798, 0.17940738233766393, 0.18878887596287638, 0.19863321183006805, 0.17529178868918072, 0.16031938933739076, 0.14523674017493338, 0.1485623484874377, 0.16530262605817156, 0.133065851593692, 0.14084638919823567, 0.16645814222506627, 0.20205648919117675, 0.13321523135919258, 0.14721083864073717, 0.17934155884552175, 0.21872976035765085, 0.139052549610509, 0.15271895391623946, 0.17032519278179195, 0.19248192142144852, 0.14842691928599178, 0.1573848662567285, 0.17165509501346896, 0.19052309210493062, 0.000984188563471946, 0.041219122675139906, 0.05845655156647884, 0.06838690151712157, 0.07957970324308138, 0.06921953585313866, 0.08608597886346912, 0.09402023860263312, 0.09865049201327444, 0.05759521252372692, 0.07505122623285379, 0.077220641659858, 0.07878878420367921, 0.05270806431255903, 0.06953695642679517, 0.06838115015763523, 0.06792406775451935, 0.05728348639407655, 0.0679407535120696, 0.06659948881428471, 0.06679679582334122];

    for (int i = 0; i < numLandmarks; i++) {
      featuresModel[i] =
          ((landmarks[i]['x'] as double) - meanFactor[i]) / stdFactor[i];
    }
    for (int i = 0; i < numLandmarks; i++) {
      featuresModel[numLandmarks + i] =
          ((landmarks[i]['y'] as double) - meanFactor[numLandmarks + i]) /
          stdFactor[numLandmarks + i];
    }
    for (int i = 0; i < numLandmarks; i++) {
      featuresModel[2 * numLandmarks + i] =
          ((landmarks[i]['z'] as double) - meanFactor[2 * numLandmarks + i]) /
          stdFactor[2 * numLandmarks + i];
    }

    return [featuresModel];
  }

  RecognitionResult _processOutput(List<double> output) {
    // Find the index of the highest confidence value
    // AppLogger.info('Stage2 Output: $output');
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

  // Generate mock recognition result for environments without MediaPipe
  RecognitionResult? _generateMockResult() {
    // Calculate an index from 0-24 based on row and col
    // Random confidence between 0.6 and 0.95
    final random = math.Random();
    final index = random.nextInt(outputs.length);
    final confidence = 0.3 + (random.nextDouble() * 0.65);

    return RecognitionResult(character: outputs[index], confidence: confidence);
  }

  void dispose() {
    if (!_isMockStage2Enabled) {
      _interpreter?.close();
      _interpreter = null;
    }
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
