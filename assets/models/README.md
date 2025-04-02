# ISLE - Sign Language Model

This directory should contain the following model files:

1. `hand_landmarker.task` - MediaPipe hand landmark detection model
2. `hand_sign_model.tflite` - TFLite model trained to recognize 28 outputs (a-z letters, space, delete) from hand landmarks.

## Integration Instructions

### hand_landmarker.task

The app is prepared for using MediaPipe's hand_landmarker.task but requires manual integration:

1. Obtain the MediaPipe hand_landmarker.task binary file
2. Place it in this directory
3. The app will automatically copy it to the appropriate location when it first runs

**Note:** Until the hand_landmarker.task file is provided, the app will use mock data for demonstration purposes.

### hand_sign_model.tflite

This model processes the hand landmarks to recognize sign language characters:

1. Ensure this file is placed in this directory
2. The app will automatically copy it to the appropriate location

## Model Details

The app uses a two-stage approach:
1. MediaPipe Tasks hand_landmarker.task is used to detect hand landmarks
2. The TFLite model in this directory interprets these landmarks to recognize sign language characters

## Input Format

### hand_landmarker.task
- Input: Camera image
- Output: 21 hand landmarks (x, y coordinates for each landmark)

### hand_sign_model.tflite
- Input: Array of 21 hand landmarks (x, y coordinates for each landmark) 
- Total input dimensions: 21 × 2 = 42 features
- Output: 28 classes: 'a' to 'z', 'space', 'delete'

## Performance

- Optimized for mobile performance
- Target inference time: <50ms
- Recognition rate: 3-4 inferences per second

For demonstration purposes, the app includes a placeholder mechanism that simulates model output. 