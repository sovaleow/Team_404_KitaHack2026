import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'services/ml_ocr.dart';
import 'services/image_labeler.dart';

// --- GEMINI SERVICE ---
class GeminiService {
  static const String _apiKey = 'AIzaSyDpBrahRZucJjvdbJosl7Nm5cDqqv759I4';
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
  }

  Future<String> getRecipes(String itemName) async {
    try {
      final prompt = 'Give me this "$itemName" recipes and how to made. Keep it short and easy to read.';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'AI could not think of recipes.';
    } catch (e) {
      return 'AI Error: Check internet connection.'; 
    }
  }

  Future<String> getSmartDetails(String itemName) async {
    try {
      final prompt = 'How should I store "$itemName" to last longer in Malaysia? Also, what are its main ingredients or nutritional facts?';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'No details available.';
    } catch (e) {
      return 'Error fetching AI tips.';
    }
  }

  Future<String> chat(String userMessage) async {
    try {
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, primary: Colors.green.shade700),
        useMaterial3: true,
        cardTheme: CardThemeData(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
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
      
      if (!mounted) return;
      Navigator.pop(context);

      final newItem = await Navigator.push<GroceryItem>(context, MaterialPageRoute(builder: (context) => AddItemPage(
        initialName: labelData.itemName ?? analysis.name,
        initialCategory: analysis.category,
        suggestions: analysis.suggestions,
        imageFile: File(photo.path),
        initialExpiry: labelData.expiryDate ?? DateTime.now().add(const Duration(days: 7)),
        isDateDetected: labelData.dateDetected,
      )));

      if (newItem != null && mounted) {
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
      appBar: AppBar(
        title: const Text('Smart Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green.shade50,
      ),
      body: Column(children: [
        _buildTabs(),
        _buildList(),
      ]),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(heroTag: 'chat', onPressed: () => _showChat(), child: const Icon(Icons.chat_bubble)),
          const SizedBox(height: 12),
          FloatingActionButton.small(heroTag: 'add', backgroundColor: Colors.white, onPressed: () async {
            final newItem = await Navigator.push<GroceryItem>(context, MaterialPageRoute(builder: (context) => AddItemPage(initialName: '', initialCategory: '', suggestions: [], initialExpiry: DateTime.now().add(const Duration(days: 7)), isDateDetected: true)));
            if (newItem != null && mounted) setState(() => _allItems.insert(0, newItem));
          }, child: const Icon(Icons.add, color: Colors.green)),
          const SizedBox(height: 12),
          FloatingActionButton(heroTag: 'scan', onPressed: _scanItem, child: const Icon(Icons.qr_code_scanner)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const cats = ['Total Items', 'Almost Expired', 'Expired'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.green.shade50,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: cats.map((c) {
        bool selected = _selectedCategory == c;
        return InkWell(
          onTap: () => setState(() => _selectedCategory = c),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c, style: TextStyle(color: selected ? Colors.green.shade800 : Colors.black54, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              if (selected) Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 40, color: Colors.green.shade800)
            ],
          ),
        );
      }).toList()),
    );
  }

  Widget _buildList() {
    final filtered = _selectedCategory == 'Almost Expired' ? _allItems.where((i) => i.isAlmostExpired).toList() : _selectedCategory == 'Expired' ? _allItems.where((i) => i.isExpired).toList() : _allItems;
    if (filtered.isEmpty) return const Expanded(child: Center(child: Text('Inventory is empty.')));
    
    return Expanded(child: ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: filtered.length, 
      itemBuilder: (context, i) {
        final item = filtered[i];
        final days = item.expiryDate.difference(DateTime.now()).inDays;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8), 
              child: item.image != null 
                ? Image.file(item.image!, width: 50, height: 50, fit: BoxFit.cover) 
                : Container(width: 50, height: 50, color: Colors.green.shade100, child: const Icon(Icons.inventory_2, color: Colors.green)),
            ),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: ${item.category}'),
                Text(
                  item.isExpired ? 'Expired!' : 'Expires in $days days', 
                  style: TextStyle(color: item.isExpired ? Colors.red : item.isAlmostExpired ? Colors.orange : Colors.green.shade700, fontWeight: FontWeight.w600)
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailPage(item: item))),
          )
        );
      }
    ));
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
      appBar: AppBar(title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.image != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(item.image!, height: 220, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 24),
        Row(children: [
          _infoChip(Icons.category, item.category),
          const SizedBox(width: 8),
          _infoChip(Icons.numbers, 'Qty: ${item.quantity}'),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: item.isExpired ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.event, color: item.isExpired ? Colors.red : Colors.green),
            const SizedBox(width: 12),
            Text('Expiry Date: ${item.expiryDate.toString().split(' ')[0]}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.isExpired ? Colors.red : Colors.green.shade900)),
          ]),
        ),
        const Divider(height: 48),
        const Text('AI Storage Tips:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FutureBuilder(future: gemini.getSmartDetails(item.name), builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          return Text(snapshot.data ?? 'No info found.', style: const TextStyle(fontSize: 15, height: 1.5));
        }),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _showRecipes(context), icon: const Icon(Icons.restaurant_menu), label: const Text('Suggest Recipes'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))),
      ])),
    );
  }

  Widget _infoChip(IconData icon, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)]));

  void _showRecipes(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Center(child: Text('AI Recipe Ideas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      const Divider(height: 30),
      Expanded(child: SingleChildScrollView(child: FutureBuilder(future: gemini.getRecipes(item.name), builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        return Text(snapshot.data ?? 'Asking AI for recipes...', style: const TextStyle(fontSize: 15, height: 1.6));
      }))),
    ])));
  }
}

// --- ADD ITEM PAGE ---
class AddItemPage extends StatefulWidget {
  final String initialName; final String initialCategory; final List<String> suggestions; final File? imageFile; final DateTime initialExpiry; final bool isDateDetected;
  const AddItemPage({super.key, required this.initialName, required this.initialCategory, required this.suggestions, this.imageFile, required this.initialExpiry, required this.isDateDetected});
  @override State<AddItemPage> createState() => _AddItemPageState();
}
class _AddItemPageState extends State<AddItemPage> {
  late TextEditingController _name, _cat, _qty; late DateTime _expiry;
  @override void initState() { super.initState(); _name = TextEditingController(text: widget.initialName); _cat = TextEditingController(text: widget.initialCategory); _qty = TextEditingController(text: '1'); _expiry = widget.initialExpiry; }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Add Item')), body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.imageFile != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(widget.imageFile!, height: 180, width: double.infinity, fit: BoxFit.cover)),
      const SizedBox(height: 16),
      if (widget.suggestions.isNotEmpty) ...[
        const Text('AI Suggestions:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: widget.suggestions.map((s) => ActionChip(label: Text(s), onPressed: () => setState(() => _name.text = s))).toList()),
        const SizedBox(height: 16),
      ],
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_basket))),
      const SizedBox(height: 16),
      TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category))),
      const SizedBox(height: 16),
      TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number),
      const SizedBox(height: 16),
      if (!widget.isDateDetected) 
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Expiry date not found on label. Please set it manually.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
          ]),
        ),
      ListTile(title: const Text('Expiry Date'), subtitle: Text('${_expiry.toLocal()}'.split(' ')[0]), trailing: const Icon(Icons.calendar_today), onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _expiry, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 3650)));
        if (d != null) setState(() => _expiry = d);
      }, tileColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, GroceryItem(name: _name.text, category: _cat.text, quantity: int.tryParse(_qty.text) ?? 1, expiryDate: _expiry, addedDate: DateTime.now(), image: widget.imageFile)), child: const Text('Add to Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
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
    setState(() { _msgs.add({'r': 'user', 't': userMsg}); _controller.clear(); _isLoading = true; });
    final aiMsg = await gemini.chat(userMsg);
    if (!mounted) return;
    setState(() { _msgs.add({'r': 'ai', 't': aiMsg}); _isLoading = false; });
  }

  @override Widget build(BuildContext context) {
    return Container(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 16, left: 16, right: 16), height: MediaQuery.of(context).size.height * 0.8, child: Column(children: [
      const Text('AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Divider(),
      Expanded(child: ListView.builder(itemCount: _msgs.length, itemBuilder: (context, i) => _chatBubble(_msgs[i]))),
      if (_isLoading) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: 'Ask about recipes...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)), contentPadding: const EdgeInsets.symmetric(horizontal: 20)))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _send, icon: const Icon(Icons.send))
      ])),
    ]));
  }

  Widget _chatBubble(Map<String, String> m) {
    bool isUser = m['r'] == 'user';
    return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.symmetric(vertical: 6), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7), decoration: BoxDecoration(color: isUser ? Colors.green.shade700 : Colors.grey.shade200, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isUser ? 16 : 0), bottomRight: Radius.circular(isUser ? 0 : 16))), child: Text(m['t'] ?? '', style: TextStyle(color: isUser ? Colors.white : Colors.black87))));
  }
}
