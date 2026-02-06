// lib/services/image_labeler.dart
import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ImageLabelerService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  /// Returns a list of labels detected in the image
  Future<List<String>> labelImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final List<ImageLabel> labels = await _labeler.processImage(inputImage);
    return labels.map((l) => l.label).toList();
  }

  void dispose() {
    _labeler.close();
  }
}

/// Map labels to your app categories
String mapLabelsToCategory(List<String> labels) {
  if (labels.any((l) => ['milk', 'cheese', 'yogurt', 'egg'].contains(l.toLowerCase()))) {
    return 'Dairy';
  } else if (labels.any((l) => ['apple', 'banana', 'avocado', 'orange'].contains(l.toLowerCase()))) {
    return 'Fruit';
  } else if (labels.any((l) => ['bread', 'flour', 'rice', 'pasta'].contains(l.toLowerCase()))) {
    return 'Pantry';
  } else {
    return 'Other';
  }
}
