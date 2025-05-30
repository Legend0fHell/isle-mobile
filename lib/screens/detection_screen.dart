import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

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
  
  // For blinking cursor
  bool _showCursor = true;
  late Timer _cursorTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  
  @override
  void initState() {
    super.initState();
    // Set up cursor blinking timer
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _cursorTimer.cancel();
    _removeOverlay();
    super.dispose();
  }
  
  // Show the suggestion dropdown
  void _showSuggestions(BuildContext context, List<String> suggestions, String currentWord, TextInputService service) {
    _removeOverlay();
    
    // Only show if we have suggestions
    if (suggestions.isEmpty) return;
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 32, // Adjust width to match input field
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 42.0), // Position below the input field
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  final matchIndex = suggestion.toLowerCase().indexOf(currentWord.toLowerCase());
                  
                  return InkWell(
                    onTap: () {
                      service.selectSuggestion(suggestion);
                      _removeOverlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            // Text before match (could be empty)
                            if (matchIndex > 0)
                              TextSpan(
                                text: suggestion.substring(0, matchIndex),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            // Matching part (user's current input)
                            if (matchIndex >= 0)
                              TextSpan(
                                text: suggestion.substring(
                                  matchIndex, 
                                  matchIndex + currentWord.length > suggestion.length 
                                    ? suggestion.length 
                                    : matchIndex + currentWord.length
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            // Text after match (the completion)
                            if (matchIndex >= 0 && matchIndex + currentWord.length < suggestion.length)
                              TextSpan(
                                text: suggestion.substring(matchIndex + currentWord.length),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) => const Divider(height: 1),
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }
  
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    // Get available screen dimensions
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview - take only what's needed for a square
            // Maximum width of 90% of screen width
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: HandSignDetectorWidget(
                previewWidth: screenSize.width * 0.9, // 90% of screen width
                confidenceThreshold: 0.65,
                showDetectionFeedback: true,
                showRecognitionInfo: true,
                showModelStatus: true,
                showGuidance: true,
                controller: _detectorController,
                consecutiveThreshold: 5,
              ),
            ),
            
            // Spacer that will take minimal space
            const SizedBox(height: 8),
            
            // Text input section - Expanded to take all remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    // Label and buttons row
                    SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Text Input label
                          const Text(
                            "Text Input",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          // Control buttons (right-aligned)
                          Consumer<TextInputService>(
                            builder: (context, service, _) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.backspace),
                                    onPressed: () => service.backspace(),
                                    tooltip: 'Backspace',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.space_bar),
                                    onPressed: () => service.selectSuggestion(" "),
                                    tooltip: 'Add Space',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.cameraswitch),
                                    onPressed: () async {
                                      final success = await _detectorController.toggleCamera();
                                      if (!success && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to switch camera. Please try again.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    tooltip: 'Switch Camera',
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Text input field - use all remaining space
                    Expanded(
                      child: Consumer<TextInputService>(
                        builder: (context, service, child) {
                          final String currentWord = service.currentWord;
                          final String fullText = service.text;
                          final List<String> suggestions = service.suggestions;
                          
                          // Get the first suggestion for inline completion
                          String? firstSuggestion = suggestions.isNotEmpty ? suggestions[0] : null;
                          String? completion;
                          
                          // Calculate the completion part
                          if (firstSuggestion != null && currentWord.isNotEmpty && 
                              firstSuggestion.startsWith(currentWord.toLowerCase())) {
                            completion = firstSuggestion.substring(currentWord.length);
                          }
                          
                          // Show suggestions dropdown if we have any
                          if (suggestions.isNotEmpty && currentWord.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showSuggestions(context, suggestions, currentWord, service);
                            });
                          } else {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _removeOverlay();
                            });
                          }

                          return CompositedTransformTarget(
                            link: _layerLink,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.blue.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              alignment: Alignment.topLeft,
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    // Past text
                                    if (fullText.isNotEmpty)
                                      TextSpan(
                                        text: "$fullText ",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      
                                    // Current word
                                    TextSpan(
                                      text: currentWord,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    
                                    // Cursor
                                    WidgetSpan(
                                      child: _showCursor
                                          ? Container(
                                              width: 2,
                                              height: 18,
                                              color: Colors.blue,
                                              margin: const EdgeInsets.symmetric(horizontal: 2),
                                            )
                                          : const SizedBox(width: 6),
                                    ),
                                    
                                    // Completion suggestion
                                    if (completion != null)
                                      TextSpan(
                                        text: completion,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}