// imgLib -> Image package from https://pub.dartlang.org/packages/image
import 'dart:typed_data';

import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';

Future<Uint8List> convertImage(CameraImage image, {int rotation = 0}) async {
  try {
    imglib.Image img = imglib.Image(
      width: image.width,
      height: image.height,
    ); // Create Image buffer
    if (image.format.group == ImageFormatGroup.yuv420) {
      img = _convertYUV420(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      img = _convertBGRA8888(image);
    }

    // Crop to square
    int minSize = img.width < img.height ? img.width : img.height;
    int xOffset = (img.width - minSize) ~/ 2;
    int yOffset = (img.height - minSize) ~/ 2;
    img = imglib.copyCrop(
      img,
      x: xOffset,
      y: yOffset,
      width: minSize,
      height: minSize,
    );

    // Rotate the image if needed
    if (rotation != 0) {
      img = imglib.copyRotate(img, angle: rotation);
    }

    // convert img to jpg that supports Bitmap.Config.ARGB_8888
    Uint8List jpgBytes = imglib.encodeJpg(img, quality: 60);
    return jpgBytes;
  } catch (e) {
    return Uint8List(0);
  }
}

// CameraImage BGRA8888 -> PNG
// Color
imglib.Image _convertBGRA8888(CameraImage image) {
  return imglib.Image.fromBytes(
    width: image.planes[0].width!,
    height: image.planes[0].height!,
    bytes: image.planes[0].bytes.buffer,
    order: imglib.ChannelOrder.bgra,
  );
}

// CameraImage YUV420_888 -> PNG -> Image (compresion:0, filter: none)
// Black
imglib.Image _convertYUV420(CameraImage cameraImage) {
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  final yBuffer = cameraImage.planes[0].bytes;
  final uBuffer = cameraImage.planes[1].bytes;
  final vBuffer = cameraImage.planes[2].bytes;

  final int yRowStride = cameraImage.planes[0].bytesPerRow;
  final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  final image = imglib.Image(width: imageWidth, height: imageHeight);

  for (int h = 0; h < imageHeight; h++) {
    int uvh = (h / 2).floor();

    for (int w = 0; w < imageWidth; w++) {
      int uvw = (w / 2).floor();

      final yIndex = (h * yRowStride) + (w * yPixelStride);

      final int y = yBuffer[yIndex];

      final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

      final int u = uBuffer[uvIndex];
      final int v = vBuffer[uvIndex];

      int r = (y + v * 1436 / 1024 - 179).round();
      int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
      int b = (y + u * 1814 / 1024 - 227).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      // Set the pixel with rotated coordinates
      image.setPixelRgb(w, h, r, g, b);
    }
  }

  return image;
}
