class RecognitionResult {
  final String character;
  final double confidence;
  final String delegateType;

  RecognitionResult({
    this.character = 'A',
    this.confidence = 0.99,
    this.delegateType = 'CPU',
  });

  bool get isDelete => character == 'delete';
  bool get isSpace => character == 'space';
  bool get isAlphabetic => !isDelete && !isSpace;

  @override
  String toString() =>
      'RecognitionResult(character: $character, confidence: ${confidence.toStringAsFixed(2)})';
}

class HandLandmark {
  final double x;
  final double y;

  HandLandmark({required this.x, required this.y});

  @override
  String toString() => 'HandLandmark(x: $x, y: $y)';
}
