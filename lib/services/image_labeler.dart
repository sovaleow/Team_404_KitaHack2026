// lib/services/image_labeler.dart
import 'dart:io';
import 'dart:convert';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
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
  Map<String, String> _memory = {};

  static const Set<String> _whitelist = {
    // Fruit & Veg
    'apple', 'banana', 'orange', 'broccoli', 'cabbage', 'onion', 'milk', 'egg', 'tomato',
    'potato', 'carrot', 'cucumber', 'lemon', 'pineapple', 'pepper', 'corn', 'grape',
    'strawberry', 'mango', 'pear', 'bread', 'cheese', 'yogurt', 'bok choy',
    // Meat & Protein
    'chicken', 'fish', 'meat', 'beef', 'mutton', 'lamb', 'pork', 'shrimp', 'prawn',
    'crab', 'squid', 'duck', 'anchovies', 'salmon', 'tuna', 'ayam', 'ikan', 'daging',
    'ikan bilis', 'udang'
  };

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('ai_learning_map');
    if (saved != null) _memory = Map<String, String>.from(json.decode(saved));

    if (_labeler != null) return;
    try {
      _labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.4));
    } catch (e) { print('AI Init Error: $e'); }
  }

  Future<DetectionResult> analyzeImage(File imageFile, String ocrText) async {
    if (_labeler == null) await initialize();
    try {
      final results = await _labeler!.processImage(InputImage.fromFile(imageFile));
      final Set<String> suggestions = {};
      final String lowerOcr = ocrText.toLowerCase();

      // Priority 1: Check OCR for local BM/EN names (Ayam, Ikan, etc)
      for (var g in _whitelist) {
        if (lowerOcr.contains(g)) suggestions.add(_capitalize(g));
      }

      // Priority 2: Check user-taught memory
      for (var r in results) {
        if (_memory.containsKey(r.label)) suggestions.add(_memory[r.label]!);
      }

      // Priority 3: Add ML labels that match whitelist
      for (var r in results) {
        if (_whitelist.any((g) => r.label.toLowerCase().contains(g))) {
          suggestions.add(_capitalize(r.label));
        }
      }

      if (suggestions.isEmpty) {
        return DetectionResult(
          name: results.isNotEmpty ? _capitalize(results.first.label) : (lowerOcr.isNotEmpty ? _capitalize(lowerOcr.split('\n').first) : 'Scan Grocery'),
          category: _mapToCategory(lowerOcr),
          suggestions: [],
          rawLabels: results
        );
      }

      return DetectionResult(
        name: suggestions.first,
        category: _mapToCategory(suggestions.first),
        suggestions: suggestions.skip(1).take(5).toList(),
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
    if (RegExp(r'apple|banana|orange|fruit|grape|mango|pear|nanas|betik|epal|pisang|oren').hasMatch(n)) return 'Fruit';
    if (RegExp(r'broccoli|cabbage|onion|veg|cucumber|bok choy|tomato|potato|carrot|sawi|kangkung|bayam|kubis|bawang|lobak').hasMatch(n)) return 'Vegetable';
    if (RegExp(r'milk|cheese|dairy|egg|yogurt|susu|telur').hasMatch(n)) return 'Dairy';
    if (RegExp(r'chicken|fish|meat|beef|mutton|lamb|pork|shrimp|prawn|crab|squid|duck|anchovies|ayam|ikan|daging|udang|sotong|bilis').hasMatch(n)) return 'Meat & Seafood';
    return 'Other';
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void dispose() => _labeler?.close();
}
