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
    'delete',
    'space',
  ];

  Interpreter? _interpreter;
  bool _isInitialized = false;
  final _throttler = Throttler(duration: const Duration(milliseconds: 100));
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
    final List<double> meanFactor = [
      0.5419437077526678,
      0.616730936070806,
      0.6487047036860216,
      0.6183346727293442,
      0.5746313981626426,
      0.5840076734633878,
      0.5712668482795434,
      0.5660286739265517,
      0.5616850953877907,
      0.5230751632011637,
      0.5065727186410683,
      0.5167070778227895,
      0.5253724165254144,
      0.47147492330699475,
      0.4552146607600344,
      0.48479285064956124,
      0.5085584222827361,
      0.42775488106286336,
      0.41433731494068793,
      0.4329509718506447,
      0.44839534775397444,
      0.7255848991638082,
      0.6727956943252088,
      0.5910785003718338,
      0.5292642066533509,
      0.5001440052168256,
      0.4649293639198329,
      0.3829101421587008,
      0.36941637974852637,
      0.3604044298357987,
      0.46965288338434413,
      0.3965848443809521,
      0.4122057636342468,
      0.41893299079506974,
      0.4949671921766374,
      0.4431561743391854,
      0.4865196801325793,
      0.5138958719628777,
      0.5336763822848766,
      0.4905714074595389,
      0.5099867985923178,
      0.5234113998550242,
      2.0155512734420954e-07,
      -0.050719170986773116,
      -0.07356407381545482,
      -0.09315592526405145,
      -0.10986413127160025,
      -0.0410851505750376,
      -0.08617153094100448,
      -0.11831519212562024,
      -0.13749346005626376,
      -0.04198371736135427,
      -0.09131830918247856,
      -0.11714739859530511,
      -0.1279581801312961,
      -0.04992965242967014,
      -0.10712899529985505,
      -0.11893249580834712,
      -0.11428224649393331,
      -0.06172388749399453,
      -0.10326410833390039,
      -0.10524468514974232,
      -0.09863711466182137,
    ];
    final List<double> stdFactor = [
      0.18445904246806905,
      0.14955120614094736,
      0.13937295722087506,
      0.1554334255652803,
      0.18239860414871312,
      0.14269898046039925,
      0.16091207146318792,
      0.18351895402760213,
      0.20833723936062587,
      0.13725449539763404,
      0.1445245384196261,
      0.15642039225842913,
      0.17300457719245668,
      0.1400745934421085,
      0.14342562381493426,
      0.15207464446943605,
      0.16119404905328208,
      0.15293979129292845,
      0.15540704122658464,
      0.16646309462792036,
      0.17865524401600794,
      0.17964139413368288,
      0.16316046191784242,
      0.14609235982706362,
      0.14742515949526308,
      0.1614055167398779,
      0.13600248418822558,
      0.14046774957932323,
      0.16488136115940644,
      0.20158480333228168,
      0.1349482614418703,
      0.14429994132455173,
      0.17849814726115107,
      0.22066743567347538,
      0.13923276574567695,
      0.14916005217480713,
      0.17012295761483393,
      0.19523187543357923,
      0.147767699120589,
      0.15407221918059405,
      0.17065981433638983,
      0.19196120271865658,
      7.136351400077437e-07,
      0.04222975215401163,
      0.05987141124365743,
      0.06982581584636993,
      0.08107505526410394,
      0.0691470032629881,
      0.08612902333612324,
      0.09464740795852226,
      0.09966053346375396,
      0.056649754363378775,
      0.07494612087808136,
      0.07803636120282648,
      0.07982674656965198,
      0.05174536369109155,
      0.07024468655183613,
      0.0697248313257596,
      0.0693084802937031,
      0.05704100357661429,
      0.06892404881049508,
      0.06773325660030974,
      0.067832082364442,
    ];

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
