# ISLE - Interactive Sign Language Engagement

A Flutter mobile app that recognizes hand signs in real-time and converts them to text. Supports Android and iOS only.

## Overview

ISLE (Interactive Sign Language Engagement) uses the device's camera to recognize hand signs and translate them into text. The app employs a two-stage pipeline:

1. **Hand Landmark Detection**: Uses MediaPipe/Google ML Kit to extract hand landmarks from a live video stream
2. **Sign Recognition**: Processes these landmarks with a lightweight model to interpret and convert them into one of 28 outputs (a-z, space, delete)

The recognized characters are stored to form words and sentences, with an auto-completion UI to assist users.

## Features

- **Real-time Recognition**: Translates sign language into text as you sign
- **Interactive UI**: 
  - Live camera feed with hand landmark visualization
  - Text display with current word highlighting
  - Auto-completion suggestions to speed up sentence formation
- **Camera Controls**: Toggle between front and back cameras
- **Editing Tools**: Delete functionality for correcting input

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio / XCode for mobile deployment
- Physical device recommended (for better camera performance)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/isle-mobile.git

# Navigate to the project directory
cd isle-mobile

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Adding the ML Model

For the app to fully function, you need to add a TFLite model for sign recognition:

1. Place your `hand_sign_model.tflite` in the `assets/models/` directory
2. Ensure the model accepts 63 inputs (21 landmarks with x,y,z coordinates)
3. The model should output 28 classes (a-z, space, delete)

See the [model README](assets/models/README.md) for more details.

## Performance Goals

- 3-4 recognitions per second (roughly every 250-333ms)
- Each inference should complete in under 50ms
- Optimized for battery efficiency

## Technical Stack

- **Framework**: Flutter (Android and iOS)
- **Camera**: Flutter camera plugin
- **ML Processing**:
  - Google ML Kit for hand landmark detection
  - TFLite Flutter for sign language model inference
- **State Management**: Provider
- **Permissions**: Permission Handler
- **UI Components**: Flutter SpinKit for loading animations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- MediaPipe for the hand landmark detection technology
- Flutter team for the excellent cross-platform framework
- The sign language community for inspiration and guidance
