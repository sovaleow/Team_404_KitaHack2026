// lib/services/ml_ocr.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MlOcr {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts text from a given image file
  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

/// Optional: Parse expiry date from extracted text (basic example)
DateTime? parseExpiryDate(String text) {
  final RegExp dateRegex = RegExp(r'(\d{2})[\/\-](\d{2})[\/\-](\d{4})'); // dd/mm/yyyy
  final match = dateRegex.firstMatch(text);
  if (match != null) {
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    return DateTime(year, month, day);
  }
  return null;
}
