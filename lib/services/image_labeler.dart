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
    'apple', 'banana', 'orange', 'broccoli', 'cabbage', 'onion', 'milk', 'egg', 'tomato',
    'potato', 'carrot', 'cucumber', 'lemon', 'pineapple', 'pepper', 'corn', 'grape',
    'strawberry', 'mango', 'pear', 'bread', 'cheese', 'yogurt', 'bok choy',
    'chicken', 'fish', 'meat', 'beef', 'mutton', 'lamb', 'pork', 'shrimp', 'prawn',
    'crab', 'squid', 'duck', 'anchovies', 'salmon', 'tuna', 'ayam', 'ikan', 'daging',
    'ikan bilis', 'udang', 'kobis', 'kubis', 'sawi', 'garlic', 'petai', 'betik', 'papaya', 'halia', 'ginger'
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

      for (var g in _whitelist) {
        if (lowerOcr.contains(g)) suggestions.add(_capitalize(g));
      }

      for (var r in results) {
        if (_memory.containsKey(r.label)) suggestions.add(_memory[r.label]!);
      }

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
    // Accurate Categorization per User Request:
    // FRUITS (Including Papaya, Watermelon, Cucumber)
    if (RegExp(r'apple|banana|orange|fruit|grape|mango|pear|nanas|betik|epal|pisang|oren|papaya|watermelon|tembikai|cucumber|timun').hasMatch(n)) return 'Fruits';
    // VEGETABLES (Including Bok Choy, Garlic, Onion, Ginger)
    if (RegExp(r'broccoli|cabbage|kobis|kubis|onion|bawang|veg|bok choy|sawi|tomato|potato|kentang|carrot|lobak|garlic|halia|ginger').hasMatch(n)) return 'Vegetables';
    // DAIRY
    if (RegExp(r'milk|susu|cheese|dairy|egg|telur|yogurt').hasMatch(n)) return 'Dairy';
    // MEAT & SEAFOOD
    if (RegExp(r'chicken|ayam|fish|ikan|meat|daging|beef|lembu|lamb|kambing|duck|itik|udang|prawn|sotong|bilis').hasMatch(n)) return 'Meat & Seafood';

    return 'Dry/Wet Food';
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void dispose() => _labeler?.close();
}
