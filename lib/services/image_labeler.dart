// lib/services/image_labeler.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetectionResult {
  final String name;
  final String category;
  final List<String> suggestions;
  final List<ImageLabel> rawLabels;

  DetectionResult({required this.name, required this.category, required this.suggestions, required this.rawLabels});
}

class ImageLabelerService {
  ImageLabeler? _labeler;
  List<String>? _labels;
  Map<String, String> _memory = {};

  static const Set<String> _whitelist = {
    'apple', 'banana', 'orange', 'broccoli', 'cabbage', 'onion', 'milk', 'egg', 'tomato', 
    'potato', 'carrot', 'cucumber', 'lemon', 'pineapple', 'pepper', 'corn', 'grape',
    'strawberry', 'mango', 'pear', 'bread', 'cheese', 'yogurt', 'meat', 'fish', 'bok choy'
  };

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('ai_learning_map');
    if (saved != null) _memory = Map<String, String>.from(json.decode(saved));

    if (_labeler != null) return;
    try {
      final modelPath = await _getModelPath('assets/ml/food_model.tflite');
      _labeler = ImageLabeler(options: LocalLabelerOptions(modelPath: modelPath, confidenceThreshold: 0.05));
      _labels = _getGroceryLabels();
    } catch (e) { print('AI Init Error: $e'); }
  }

  Future<DetectionResult> analyzeImage(File imageFile, String ocrText) async {
    if (_labeler == null) await initialize();
    try {
      final results = await _labeler!.processImage(InputImage.fromFile(imageFile));
      final Set<String> suggestions = {};
      final String lowerOcr = ocrText.toLowerCase();

      for (var r in results) {
        if (_memory.containsKey(r.label)) suggestions.add(_memory[r.label]!);
      }
      for (var g in _whitelist) {
        if (lowerOcr.contains(g)) suggestions.add(_capitalize(g));
      }
      for (var r in results) {
        int? idx = int.tryParse(r.label);
        String name = (idx != null && idx < _labels!.length) ? _labels![idx] : r.label;
        if (_whitelist.any((g) => name.toLowerCase().contains(g))) suggestions.add(_capitalize(name));
      }

      if (suggestions.isEmpty) return DetectionResult(name: 'Scan Grocery', category: 'Other', suggestions: [], rawLabels: results);

      return DetectionResult(
        name: suggestions.first,
        category: _mapToCategory(suggestions.first),
        suggestions: suggestions.skip(1).take(8).toList(),
        rawLabels: results,
      );
    } catch (e) { return DetectionResult(name: 'Error', category: 'Other', suggestions: [], rawLabels: []); }
  }

  Future<void> teachAI(List<ImageLabel> labels, String name) async {
    if (labels.isEmpty) return;
    _memory[labels.first.label] = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_learning_map', json.encode(_memory));
  }

  String _mapToCategory(String name) {
    final n = name.toLowerCase();
    if (RegExp(r'apple|banana|orange|fruit').hasMatch(n)) return 'Fruit';
    if (RegExp(r'broccoli|cabbage|onion|veg|cucumber|bok choy').hasMatch(n)) return 'Vegetable';
    if (RegExp(r'milk|cheese|dairy|egg').hasMatch(n)) return 'Dairy';
    return 'Other';
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  List<String> _getGroceryLabels() {
    var list = List.generate(1001, (i) => 'Item $i');
    list[948] = 'Apple'; list[954] = 'Banana'; list[950] = 'Orange';
    list[938] = 'Broccoli'; list[931] = 'Cabbage'; list[933] = 'Cucumber';
    list[937] = 'Bok Choy'; list[951] = 'Lemon'; list[928] = 'Bell Pepper';
    return list;
  }

  Future<String> _getModelPath(String asset) async {
    final path = join((await getApplicationSupportDirectory()).path, 'food_model.tflite');
    final file = File(path);
    final byteData = await rootBundle.load(asset);
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }

  void dispose() => _labeler?.close();
}
