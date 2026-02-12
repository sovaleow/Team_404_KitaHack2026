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
  final double confidence;

  DetectionResult({
    required this.name, 
    required this.category, 
    required this.suggestions,
    required this.rawLabels,
    required this.confidence,
  });
}

class ImageLabelerService {
  ImageLabeler? _labeler;
  List<String>? _labels;
  Map<String, String> _learningMemory = {};

  // --- HACKATHON OPTIMIZATION: EXPANDED GROCERY WHITELIST ---
  static const Set<String> _groceryWhitelist = {
    'apple', 'banana', 'orange', 'broccoli', 'cabbage', 'onion', 'milk', 'egg', 'tomato', 
    'potato', 'carrot', 'cucumber', 'lemon', 'pineapple', 'pepper', 'corn', 'grape',
    'strawberry', 'mango', 'pear', 'bread', 'cheese', 'yogurt', 'meat', 'fish',
    'lettuce', 'spinach', 'garlic', 'ginger', 'lime', 'watermelon', 'melon', 'avocado',
    'mushroom', 'celery', 'eggplant', 'zucchini', 'pumpkin', 'radish', 'berry', 'cherry'
  };

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('ai_learning_map');
    if (saved != null) {
      _learningMemory = Map<String, String>.from(json.decode(saved));
    }

    if (_labeler != null) return;
    try {
      final modelPath = await _getModelPath('assets/ml/food_model.tflite');
      _labeler = ImageLabeler(options: LocalLabelerOptions(modelPath: modelPath, confidenceThreshold: 0.05));
      _labels = _getMobileNetLabels();
      print('Enhanced Offline AI Model Ready');
    } catch (e) {
      print('AI Init Error: $e');
    }
  }

  Future<DetectionResult> analyzeImage(File imageFile, String ocrText) async {
    if (_labeler == null) await initialize();

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> results = await _labeler!.processImage(inputImage);
      final String lowerOcr = ocrText.toLowerCase();

      if (results.isEmpty && ocrText.isEmpty) {
        return DetectionResult(name: 'Scan Grocery', category: 'Other', suggestions: [], rawLabels: [], confidence: 0);
      }

      final List<MapEntry<String, double>> candidates = [];

      // 1. Memory & OCR (Highest Priority)
      for (var r in results) {
        if (_learningMemory.containsKey(r.label)) {
          candidates.add(MapEntry(_learningMemory[r.label]!, 1.0));
        }
      }
      for (var g in _groceryWhitelist) {
        if (lowerOcr.contains(g)) candidates.add(MapEntry(_capitalize(g), 0.95));
      }

      // 2. Map AI indices to Names and filter by Whitelist
      for (var r in results) {
        int? index = int.tryParse(r.label);
        String name = (index != null && index < _labels!.length) ? _labels![index] : r.label;
        final nameLower = name.toLowerCase();
        
        if (_groceryWhitelist.any((g) => nameLower.contains(g))) {
          candidates.add(MapEntry(_capitalize(name), r.confidence));
        }
      }

      // 3. Final Decision Logic
      if (candidates.isEmpty) {
        return DetectionResult(
          name: 'Please scan a grocery item',
          category: 'Other',
          suggestions: [],
          rawLabels: results,
          confidence: 0,
        );
      }

      candidates.sort((a, b) => b.value.compareTo(a.value));
      final List<String> uniqueSuggestions = candidates.map((e) => e.key).toSet().toList();

      final String topName = uniqueSuggestions.first;
      final double topConf = candidates.first.value;

      return DetectionResult(
        name: '$topName (${(topConf * 100).toStringAsFixed(0)}%)',
        category: _mapToCategory(topName, lowerOcr),
        suggestions: uniqueSuggestions.skip(1).take(10).toList(),
        rawLabels: results,
        confidence: topConf,
      );
    } catch (e) {
      return DetectionResult(name: 'Error', category: 'Other', suggestions: [], rawLabels: [], confidence: 0);
    }
  }

  Future<void> teachAI(List<ImageLabel> aiLabels, String finalName) async {
    if (aiLabels.isEmpty || finalName.isEmpty) return;
    _learningMemory[aiLabels.first.label] = finalName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_learning_map', json.encode(_learningMemory));
  }

  String _mapToCategory(String name, String ocr) {
    final text = (name + ' ' + ocr).toLowerCase();
    if (RegExp(r'apple|banana|orange|citrus|fruit|lemon|mango|pear|berry|melon|grape').hasMatch(text)) return 'Fruit';
    if (RegExp(r'broccoli|cabbage|onion|potato|tomato|vegetable|pepper|cucumber|bok choy|greens|lettuce').hasMatch(text)) return 'Vegetable';
    if (RegExp(r'milk|cheese|dairy|yogurt|egg|butter').hasMatch(text)) return 'Dairy';
    if (RegExp(r'bread|bakery|flour|rice|pasta|noodle').hasMatch(text)) return 'Pantry';
    return 'Other';
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  // Full MobileNet Grocery Label Mapping
  List<String> _getMobileNetLabels() {
    var list = List.generate(1001, (i) => 'Item $i');
    // Common Grocery Mappings for MobileNet V2
    list[948] = 'Granny smith apple';
    list[954] = 'Banana';
    list[950] = 'Orange';
    list[938] = 'Broccoli';
    list[931] = 'Cabbage';
    list[928] = 'Bell pepper';
    list[927] = 'Zucchini';
    list[937] = 'Cauliflower';
    list[933] = 'Cucumber';
    list[951] = 'Lemon';
    list[953] = 'Pineapple';
    list[949] = 'Strawberry';
    list[955] = 'Jackfruit';
    list[952] = 'Fig';
    list[957] = 'Pomegranate';
    list[947] = 'Mushroom';
    list[923] = 'Plate of food';
    list[929] = 'Hot pepper';
    list[935] = 'Cabbage';
    list[968] = 'Milk';
    list[924] = 'Guacamole (Avocado)';
    list[962] = 'Meat';
    list[934] = 'Zucchini';
    list[932] = 'Artichoke';
    list[936] = 'Broccoli';
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
