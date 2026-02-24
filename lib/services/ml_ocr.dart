// lib/services/ml_ocr.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LabelData {
  final String? itemName;
  final DateTime? expiryDate;
  final bool dateDetected;

  LabelData({this.itemName, this.expiryDate, this.dateDetected = false});
}

class MlOcr {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<LabelData> analyzeLabel(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final String fullText = recognizedText.text;

    final expiryDate = _extractExpiryDate(fullText);

    return LabelData(
      itemName: _extractItemName(fullText),
      expiryDate: expiryDate,
      dateDetected: expiryDate != null,
    );
  }

  String? _extractItemName(String text) {
    const keywords = [
      'apple', 'banana', 'orange', 'onion', 'garlic', 'cabbage', 'broccoli',
      'milk', 'bread', 'egg', 'tomato', 'potato', 'chicken', 'fish', 'meat',
      'beef', 'mutton', 'lamb', 'pork', 'shrimp', 'prawn', 'crab', 'squid',
      'duck', 'anchovies', 'salmon', 'tuna', 'papaya', 'epal', 'pisang', 'oren',
      'bawang', 'kubis', 'kobis', 'susu', 'roti', 'telur', 'tomat', 'kentang',
      'timun', 'halia', 'lobak', 'sawi', 'kangkung', 'bayam', 'terung',
      'cili', 'serai', 'lengkuas', 'kunyit', 'petai', 'kacang', 'bendi',
      'peria', 'labu', 'jagung', 'limau', 'tembikai', 'nanas', 'betik',
      'mangga', 'durian', 'rambutan', 'nangka', 'ayam', 'ikan', 'daging',
      'lembu', 'kambing', 'udang', 'ketam', 'sotong', 'puyuh', 'itik',
      'bilis', 'kerang', 'siput'
    ];

    final lines = text.split('\n');
    for (var line in lines) {
      final cleanLine = line.trim().toLowerCase();
      for (var k in keywords) {
        if (cleanLine.contains(k)) {
          return line.trim().toUpperCase();
        }
      }
    }
    return null;
  }

  DateTime? _extractExpiryDate(String text) {
    final dateRegex = RegExp(r'(\d{2,4}|\d{1,2})[\/\-\.\s](\d{1,2}|[a-zA-Z]{3,10})[\/\-\.\s](\d{2,4}|\d{1,2})');
    final expiryKeywords = ['bb', 'exp', 'best before', 'use by', 'guna sebelum', 'tarikh luput', 'baik sebelum'];
    
    final lines = text.split('\n');
    for (var line in lines) {
      final lowerLine = line.toLowerCase();
      for (var keyword in expiryKeywords) {
        if (lowerLine.contains(keyword)) {
          final startIndex = text.toLowerCase().indexOf(keyword);
          final searchArea = text.substring(startIndex, (startIndex + 60).clamp(0, text.length));
          final match = dateRegex.firstMatch(searchArea);
          if (match != null) return _parseFlexibleMatch(match);
        }
      }
    }
    
    final allMatches = dateRegex.allMatches(text);
    for (final match in allMatches) {
      final date = _parseFlexibleMatch(match);
      if (date != null && date.isAfter(DateTime.now().subtract(const Duration(days: 365)))) {
        return date;
      }
    }
    return null;
  }

  DateTime? _parseFlexibleMatch(RegExpMatch match) {
    try {
      String p1 = match.group(1)!;
      String p2 = match.group(2)!;
      String p3 = match.group(3)!;
      int? year, month, day;
      month = _monthToNum(p2);
      int? v1 = int.tryParse(p1);
      int? v3 = int.tryParse(p3);
      if (v1 == null || v3 == null) return null;
      if (v1 > 31) { year = v1; day = v3; }
      else if (v3 > 31) { year = v3; day = v1; }
      else { year = v3; day = v1; }
      if (year < 100) year += 2000;
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    } catch (e) { return null; }
  }

  int _monthToNum(String m) {
    if (int.tryParse(m) != null) return int.parse(m);
    const monthsMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      'mei': 5, 'ogos': 8, 'dis': 12, 'januari': 1, 'februari': 2, 'mac': 3, 'april': 4, 'julai': 7, 'september': 9, 'oktober': 10, 'november': 11, 'disember': 12
    };
    final lowerM = m.toLowerCase();
    for (var key in monthsMap.keys) { if (lowerM.startsWith(key)) return monthsMap[key]!; }
    return 1;
  }

  void dispose() => _textRecognizer.close();
}
