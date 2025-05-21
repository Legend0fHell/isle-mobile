import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/text_input_service.dart';
import '../widgets/hand_sign_detector_widget.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  // Controller for the HandSignDetectorWidget
  final HandSignDetectorController _detectorController =
      HandSignDetectorController(
        toggleCamera:
            () => Future.value(false), // Placeholder until widget initializes
      );

  @override
  Widget build(BuildContext context) {
    // return Text("idle");
    return Scaffold(
      body: Column(
        children: [
          // Hand sign detector takes 3/5 of the screen
          Expanded(
            flex: 3,
            child: HandSignDetectorWidget(
              confidenceThreshold: 0.65,
              showDetectionFeedback: true,
              showRecognitionInfo: true,
              showModelStatus: true,
              showGuidance: true,
              controller: _detectorController,
            ),
          ),

          // Text input display takes 2/5 of the screen
          Expanded(
            flex: 2,
            child: Consumer<TextInputService>(
              builder: (context, service, child) {
                final String currentWord = service.currentWord;

                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current word display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: .1),
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currentWord.isEmpty ? "..." : currentWord,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color:
                                currentWord.isEmpty
                                    ? Colors.grey
                                    : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Full text display
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              service.text,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.backspace),
                            onPressed: () => service.backspace(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.space_bar),
                            onPressed: () => service.selectSuggestion(" "),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => service.clearText(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cameraswitch),
                            onPressed: () async {
                              final success =
                                  await _detectorController.toggleCamera();

                              if (!success && mounted) {
                                // Show error snackbar if camera switch failed
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to switch camera. Please try again.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
