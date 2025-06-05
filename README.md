# ISLE - Interactive Sign Language Education

A Flutter mobile app that recognizes hand signs in real-time, converts them to text, and teach users how to do handsigns. Supports Android only.

## Overview

ISLE (Interactive Sign Language Education) uses the device's camera to recognize hand signs and translate them into text. The app employs a two-stage pipeline:

1. **Hand Landmark Detection**: Uses MediaPipe/Google ML Kit to extract hand landmarks from a live video stream
2. **Sign Recognition**: Processes these landmarks with a lightweight model to interpret and convert them into one of 29 outputs (a-z, space, delete, autocomplete)

The recognized characters are stored to form words and sentences, with an auto-completion UI to assist users.

## Features

- **Real-time Recognition**: Translates sign language into text as you sign.
- **Interactive UI**: 
  - Live camera feed with hand landmark visualization
  - Text display with current word highlighting
  - Auto-completion suggestions to speed up sentence formation.
- **Camera Controls**: Toggle between front and back cameras
- **Studying**: Dedicated features to help users mastering the handsigns!

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio for mobile deployment
- Physical device recommended (for better ML/camera performance)

### Installation

```bash
# Clone the repository
git clone https://github.com/Legend0fHell/isle-mobile.git

# Navigate to the project directory
cd isle-mobile

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### ML models

## Performance Goals

- Handsign recognitions in under 40ms.
- 4 letter classifications per second (roughly every 250ms).
- Total time of inference should be under 66ms.
- Optimized for battery efficiency.

## Technical Stack

- **Framework**: Flutter (Android)
- **Camera**: Flutter camera plugin
- **ML Processing**:
  - MediaPipe/Google ML Kit for hand landmark detection
  - TensorflowLite (LiteRT) for sign language model inference
- **State Management**: Provider
- **Permissions**: Permission Handler
