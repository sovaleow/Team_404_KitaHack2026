// lib/services/ml_ocr.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LabelData {
  final String? itemName;
  final DateTime? expiryDate;
  LabelData({this.itemName, this.expiryDate});
}

class MlOcr {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts structured data from a grocery price label
  Future<LabelData> analyzeLabel(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final String fullText = recognizedText.text;

    return LabelData(
      itemName: _extractItemName(fullText),
      expiryDate: _extractExpiryDate(fullText),
    );
  }

  /// Finds the item name by looking at lines that contain Malaysian grocery keywords
  String? _extractItemName(String text) {
    const keywords = [
      'apple', 'banana', 'orange', 'onion', 'garlic', 'cabbage', 'broccoli', 
      'milk', 'bread', 'egg', 'tomato', 'potato', 'chicken', 'fish', 'meat',
      'bok choy', 'cucumber', 'ginger', 'carrot', 'sawit', 'ayam', 'ikan'
    ];

    final lines = text.split('\n');
    for (var line in lines) {
      final cleanLine = line.trim().toLowerCase();
      for (var k in keywords) {
        if (cleanLine.contains(k)) return line.trim();
      }
    }
    return null;
  }

  /// Malaysia-specific date parser (BB, EXP, Use By)
  DateTime? _extractExpiryDate(String text) {
    // Patterns for dates: DD/MM/YYYY, DD.MM.YYYY, DDMMMYYYY
    final dateRegex = RegExp(r'(\d{1,2})[\/\-\.\s](\d{1,2}|[a-zA-Z]{3})[\/\-\.\s](\d{2,4})');
    final expiryKeywords = ['bb', 'exp', 'best before', 'use by', 'guna sebelum', 'tarikh luput'];
    
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (expiryKeywords.any((k) => line.contains(k))) {
        final match = dateRegex.firstMatch(text.substring(text.indexOf(lines[i])));
        if (match != null) return _parseMatch(match);
      }
    }
    
    final match = dateRegex.firstMatch(text);
    if (match != null) return _parseMatch(match);

    return null;
  }

  DateTime? _parseMatch(RegExpMatch match) {
    try {
      int day = int.parse(match.group(1)!);
      String monthStr = match.group(2)!;
      int year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      int month = _monthToNum(monthStr);
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  int _monthToNum(String m) {
    if (int.tryParse(m) != null) return int.parse(m);
    const months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
    final key = m.toLowerCase().substring(0, 3);
    return months[key] ?? 1;
  }

  void dispose() => _textRecognizer.close();
}
