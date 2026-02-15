import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'services/ml_ocr.dart';
import 'services/image_labeler.dart';

// --- GEMINI SERVICE ---
class GeminiService {
  // Provided API Key
  static const String _apiKey = 'AIzaSyDpBrahRZucJjvdbJosl7Nm5cDqqv759I4';
  
  late final GenerativeModel _model;

  GeminiService() {
    // FIX: Using 'gemini-pro' for guaranteed uptime and free access
    _model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
  }

  /// System-mediated recipe request
  Future<String> getRecipes(String itemName) async {
    try {
      final prompt = 'Give me this "$itemName" recipes and how to made. Keep it short and easy to read.';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'AI could not think of recipes.';
    } catch (e) {
      return 'AI Error: Check internet. Details: $e'; 
    }
  }

  /// System-mediated storage advice
  Future<String> getSmartDetails(String itemName) async {
    try {
      final prompt = 'How should I store "$itemName" to last longer in Malaysia? Also, what are its main ingredients or nutritional facts?';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'No details available.';
    } catch (e) {
      return 'Error fetching AI tips.';
    }
  }

  /// System-mediated chat: User -> App -> AI -> App -> User
  Future<String> chat(String userMessage) async {
    try {
      // The system adds context to the user message before sending to Gemini
      final prompt = 'User asks: "$userMessage". As an AI grocery assistant, provide a helpful and short reply.';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'I don\'t understand that.';
    } catch (e) {
      return 'Chat Error: $e';
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitaHackApp());
}

class KitaHackApp extends StatelessWidget {
  const KitaHackApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Smart Grocery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

// --- DATA MODELS ---
class GroceryItem {
  String name; String category; int quantity; DateTime expiryDate; final DateTime addedDate; final File? image; final String id;
  GroceryItem({required this.name, required this.category, required this.quantity, required this.expiryDate, required this.addedDate, this.image}) : id = UniqueKey().toString();
  bool get isAlmostExpired => expiryDate.difference(DateTime.now()).inDays <= 3 && !isExpired;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<GroceryItem> _allItems = [];
  final ImagePicker _picker = ImagePicker();
  final labeler = ImageLabelerService();
  String _selectedCategory = 'Total Items';

  @override void initState() { super.initState(); labeler.initialize(); }

  Future<void> _scanItem() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null || !mounted) return;
      _showLoading('Analyzing Label with AI...');
      final mlOcr = MlOcr();
      final labelData = await mlOcr.analyzeLabel(File(photo.path));
      final analysis = await labeler.analyzeImage(File(photo.path), labelData.itemName ?? "");
      mlOcr.dispose();
      Navigator.pop(context);

      final newItem = await Navigator.push<GroceryItem>(context, MaterialPageRoute(builder: (context) => AddItemPage(
        initialName: labelData.itemName ?? analysis.name,
        initialCategory: analysis.category,
        suggestions: analysis.suggestions,
        imageFile: File(photo.path),
        initialExpiry: labelData.expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      )));

      if (newItem != null) {
        await labeler.teachAI(analysis.rawLabels, newItem.name);
        setState(() => _allItems.insert(0, newItem));
      }
    } catch (e) { if (mounted) Navigator.pop(context); }
  }

  void _showLoading(String msg) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Text(msg)])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Inventory')),
      body: Column(children: [
        _buildTabs(),
        _buildList(),
      ]),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(heroTag: 'chat', mini: true, onPressed: () => _showChat(), child: const Icon(Icons.chat_bubble)),
          const SizedBox(height: 12),
          FloatingActionButton(heroTag: 'add', mini: true, backgroundColor: Colors.white, onPressed: () async {
            final newItem = await Navigator.push<GroceryItem>(context, MaterialPageRoute(builder: (context) => AddItemPage(initialName: '', initialCategory: '', suggestions: [], initialExpiry: DateTime.now().add(const Duration(days: 7)))));
            if (newItem != null) setState(() => _allItems.insert(0, newItem));
          }, child: const Icon(Icons.add, color: Colors.green)),
          const SizedBox(height: 12),
          FloatingActionButton(heroTag: 'scan', onPressed: _scanItem, child: const Icon(Icons.qr_code_scanner)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const cats = ['Total Items', 'Almost Expired', 'Expired'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: cats.map((c) => TextButton(onPressed: () => setState(() => _selectedCategory = c), child: Text(c, style: TextStyle(color: _selectedCategory == c ? Colors.green : Colors.black54, fontWeight: _selectedCategory == c ? FontWeight.bold : FontWeight.normal)))).toList()),
    );
  }

  Widget _buildList() {
    final filtered = _selectedCategory == 'Almost Expired' ? _allItems.where((i) => i.isAlmostExpired).toList() : _selectedCategory == 'Expired' ? _allItems.where((i) => i.isExpired).toList() : _allItems;
    if (filtered.isEmpty) return const Expanded(child: Center(child: Text('No items found.')));
    return Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (context, i) => Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: ListTile(
      leading: filtered[i].image != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(filtered[i].image!, width: 40, height: 40, fit: BoxFit.cover)) : const Icon(Icons.inventory_2),
      title: Text(filtered[i].name),
      subtitle: Text('Expires: ${filtered[i].expiryDate.toString().split(' ')[0]}'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailPage(item: filtered[i]))),
    ))));
  }

  void _showChat() {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => const GeminiChatSheet());
  }
}

// --- ITEM DETAIL PAGE ---
class ItemDetailPage extends StatelessWidget {
  final GroceryItem item;
  final gemini = GeminiService();
  ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.image != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(item.image!, height: 200, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Category: ${item.category}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 18)),
        ]),
        const SizedBox(height: 8),
        Text('Expiry Date: ${item.expiryDate.toString().split(' ')[0]}', style: TextStyle(fontSize: 16, color: item.isExpired ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
        const Divider(height: 40),
        const Text('System Suggestion (Storage & Info):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 8),
        FutureBuilder(future: gemini.getSmartDetails(item.name), builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(snapshot.data ?? 'No info found.'));
        }),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _showRecipes(context), icon: const Icon(Icons.restaurant_menu), label: const Text('AI Recipes Suggestions'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))),
      ])),
    );
  }

  void _showRecipes(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('System: Generating recipes from Gemini...', style: TextStyle(fontSize: 16, color: Colors.grey)),
      const Divider(),
      Expanded(child: SingleChildScrollView(child: FutureBuilder(future: gemini.getRecipes(item.name), builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        return Text(snapshot.data ?? 'Asking AI for recipes...');
      }))),
    ])));
  }
}

// --- ADD ITEM PAGE ---
class AddItemPage extends StatefulWidget {
  final String initialName; final String initialCategory; final List<String> suggestions; final File? imageFile; final DateTime initialExpiry;
  const AddItemPage({super.key, required this.initialName, required this.initialCategory, required this.suggestions, this.imageFile, required this.initialExpiry});
  @override State<AddItemPage> createState() => _AddItemPageState();
}
class _AddItemPageState extends State<AddItemPage> {
  late TextEditingController _name, _cat, _qty; late DateTime _expiry;
  @override void initState() { super.initState(); _name = TextEditingController(text: widget.initialName); _cat = TextEditingController(text: widget.initialCategory); _qty = TextEditingController(text: '1'); _expiry = widget.initialExpiry; }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Item Details')), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      if (widget.imageFile != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(widget.imageFile!, height: 200, width: double.infinity, fit: BoxFit.cover)),
      const SizedBox(height: 16),
      if (widget.suggestions.isNotEmpty) Wrap(spacing: 8, children: widget.suggestions.map((s) => ActionChip(label: Text(s), onPressed: () => setState(() => _name.text = s))).toList()),
      const SizedBox(height: 12),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      ListTile(title: const Text('Expiry Date'), subtitle: Text('${_expiry.toLocal()}'.split(' ')[0]), trailing: const Icon(Icons.calendar_today), onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _expiry, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 3650)));
        if (d != null) setState(() => _expiry = d);
      }, tileColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, GroceryItem(name: _name.text, category: _cat.text, quantity: int.tryParse(_qty.text) ?? 1, expiryDate: _expiry, addedDate: DateTime.now(), image: widget.imageFile)), child: const Text('Save to Inventory')))
    ])));
  }
}

// --- CHAT SHEET ---
class GeminiChatSheet extends StatefulWidget { const GeminiChatSheet({super.key}); @override State<GeminiChatSheet> createState() => _GeminiChatSheetState(); }
class _GeminiChatSheetState extends State<GeminiChatSheet> {
  final gemini = GeminiService(); final _controller = TextEditingController(); final List<Map<String, String>> _msgs = [];
  bool _isLoading = false;

  void _send() async {
    if (_controller.text.isEmpty || _isLoading) return;
    final userMsg = _controller.text;
    setState(() { 
      _msgs.add({'r': 'user', 't': userMsg}); 
      _controller.clear(); 
      _isLoading = true;
    });
    
    // System takes the user msg and asks Gemini
    final aiMsg = await gemini.chat(userMsg);
    
    setState(() { 
      _msgs.add({'r': 'ai', 't': aiMsg}); 
      _isLoading = false;
    });
  }

  @override Widget build(BuildContext context) {
    return Container(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 16, left: 16, right: 16), height: MediaQuery.of(context).size.height * 0.8, child: Column(children: [
      const Text('AI Grocery Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const Divider(),
      Expanded(child: ListView.builder(itemCount: _msgs.length, itemBuilder: (context, i) => Align(alignment: _msgs[i]['r'] == 'user' ? Alignment.centerRight : Alignment.centerLeft, child: Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: _msgs[i]['r'] == 'user' ? Colors.green[100] : Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Text(_msgs[i]['t'] ?? ''))))),
      if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'System: Ask about cooking...', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _send, icon: const Icon(Icons.send))
      ])),
    ]));
  }
}
