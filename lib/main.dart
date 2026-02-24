import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services/ml_ocr.dart';
import 'services/image_labeler.dart';
import 'services/local_recipes.dart';

// --- MAIN ENTRY POINT ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init failed: $e. Make sure you added google-services.json");
  }
  await NotificationService.init();
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
      home: const AuthWrapper(),
    );
  }
}

// --- AUTH WRAPPER ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data == null) return const LoginPage();
        return const HomePage();
      },
    );
  }
}

// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLogin = true;

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _googleSignIn() async {
    try {
      // FORCE ACCOUNT SELECTION
      await GoogleSignIn().signOut(); 
      
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      if (googleAuth != null) {
        final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.shopping_basket, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, child: Text(_isLogin ? 'Login' : 'Register'))),
            TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? 'Create Account' : 'I have an account')),
            const Divider(),
            SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(icon: const Icon(Icons.login), label: const Text('Sign in with Google'), onPressed: _googleSignIn)),
          ],
        ),
      ),
    );
  }
}

// --- DATA MODELS ---
class GroceryItem {
  String name; String category; int quantity; DateTime expiryDate; final DateTime addedDate; final String? imageUrl; final String id;
  GroceryItem({required this.name, required this.category, required this.quantity, required this.expiryDate, required this.addedDate, this.imageUrl, required this.id});

  Map<String, dynamic> toMap() => {
    'name': name, 'category': category, 'quantity': quantity, 'expiryDate': expiryDate.toIso8601String(), 'addedDate': addedDate.toIso8601String(), 'imageUrl': imageUrl
  };

  factory GroceryItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroceryItem(
      id: doc.id,
      name: data['name'],
      category: data['category'],
      quantity: data['quantity'],
      expiryDate: DateTime.parse(data['expiryDate']),
      addedDate: DateTime.parse(data['addedDate']),
      imageUrl: data['imageUrl'],
    );
  }

  bool get isAlmostExpired => expiryDate.difference(DateTime.now()).inDays <= 3 && !isExpired;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
}

// --- FIREBASE SERVICE ---
class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static Stream<List<GroceryItem>> getItems() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db.collection('users').doc(_uid).collection('inventory').snapshots().map((snap) => snap.docs.map((doc) => GroceryItem.fromDoc(doc)).toList());
  }

  static Future<void> addItem(GroceryItem item) async {
    if (_uid.isEmpty) return;
    await _db.collection('users').doc(_uid).collection('inventory').add(item.toMap());
  }

  static Future<void> deleteItem(String id) async {
    if (_uid.isEmpty) return;
    await _db.collection('users').doc(_uid).collection('inventory').doc(id).delete();
  }

  static Future<void> completeItem(GroceryItem item) async {
    if (_uid.isEmpty) return;
    await _db.collection('users').doc(_uid).collection('stats').add({
      'itemName': item.name,
      'date': DateTime.now().toIso8601String(),
      'status': 'used',
    });
    await deleteItem(item.id);
  }

  static Stream<QuerySnapshot> getStats() {
    if (_uid.isEmpty) return const Stream.empty();
    return _db.collection('users').doc(_uid).collection('stats').snapshots();
  }
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

      final newItemData = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (context) => AddItemPage(
        initialName: labelData.itemName ?? analysis.name,
        initialCategory: analysis.category,
        suggestions: analysis.suggestions,
        imageFile: File(photo.path),
        initialExpiry: labelData.expiryDate ?? DateTime.now().add(const Duration(days: 7)),
        isDateDetected: labelData.dateDetected,
      )));

      if (newItemData != null && mounted) {
        final item = GroceryItem(
          id: '', name: newItemData['name'], category: newItemData['category'], quantity: newItemData['quantity'],
          expiryDate: newItemData['expiryDate'], addedDate: DateTime.now()
        );
        await FirebaseService.addItem(item);
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
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StatsPage()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await GoogleSignIn().signOut(); // Ensure Google sign out
            await FirebaseAuth.instance.signOut();
          }),
        ],
        centerTitle: true,
        backgroundColor: Colors.green.shade50,
      ),
      body: Column(children: [
        _buildTabs(),
        Expanded(
          child: StreamBuilder<List<GroceryItem>>(
            stream: FirebaseService.getItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data ?? [];
              return _buildList(items);
            },
          ),
        ),
      ]),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(heroTag: 'add', backgroundColor: Colors.white, onPressed: () async {
            final data = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (context) => AddItemPage(initialName: '', initialCategory: '', suggestions: [], initialExpiry: DateTime.now().add(const Duration(days: 7)), isDateDetected: true)));
            if (data != null) {
              await FirebaseService.addItem(GroceryItem(id: '', name: data['name'], category: data['category'], quantity: data['quantity'], expiryDate: data['expiryDate'], addedDate: DateTime.now()));
            }
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

  Widget _buildList(List<GroceryItem> allItems) {
    final filtered = _selectedCategory == 'Almost Expired' ? allItems.where((i) => i.isAlmostExpired).toList() : _selectedCategory == 'Expired' ? allItems.where((i) => i.isExpired).toList() : allItems;
    if (filtered.isEmpty) return const Center(child: Text('Inventory is empty.'));
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: filtered.length, 
      itemBuilder: (context, i) {
        final item = filtered[i];
        final days = item.expiryDate.difference(DateTime.now()).inDays;
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20.0), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (direction) {
            NotificationService.cancelNotifications(item.id);
            FirebaseService.deleteItem(item.id);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} removed')));
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(width: 50, height: 50, color: Colors.green.shade100, child: const Icon(Icons.inventory_2, color: Colors.green)),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text(item.isExpired ? 'Expired!' : 'Expires in $days days', style: TextStyle(color: item.isExpired ? Colors.red : item.isAlmostExpired ? Colors.orange : Colors.green.shade700, fontWeight: FontWeight.w600)),
              trailing: IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green), onPressed: () => FirebaseService.completeItem(item)),
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailPage(item: item)));
                if (result == 'delete' && mounted) FirebaseService.deleteItem(item.id);
              },
            )
          ),
        );
      }
    );
  }
}

// --- STATS PAGE ---
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waste Reduction Stats')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          // Group by date for the graph
          Map<String, int> dailyCount = {};
          for (var doc in docs) {
            String date = (doc.data() as Map)['date'].toString().split('T')[0];
            dailyCount[date] = (dailyCount[date] ?? 0) + 1;
          }
          
          List<BarChartGroupData> barGroups = [];
          int i = 0;
          dailyCount.forEach((date, count) {
            barGroups.add(BarChartGroupData(x: i++, barRods: [BarChartRodData(toY: count.toDouble(), color: Colors.green)]));
          });

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text('Food Items Saved from Waste', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                if (barGroups.isEmpty) 
                  const Expanded(child: Center(child: Text("No data yet. Use items to see your impact!")))
                else
                  SizedBox(height: 300, child: BarChart(BarChartData(barGroups: barGroups))),
                const SizedBox(height: 20),
                Text('Total Items Saved: ${docs.length}', style: const TextStyle(fontSize: 20)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- ITEM DETAIL PAGE ---
class ItemDetailPage extends StatelessWidget {
  final GroceryItem item;
  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => Navigator.pop(context, 'delete'))],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_infoChip(Icons.category, item.category), const SizedBox(width: 8), _infoChip(Icons.numbers, 'Qty: ${item.quantity}')]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: item.isExpired ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [Icon(Icons.event, color: item.isExpired ? Colors.red : Colors.green), const SizedBox(width: 12), Text('Expiry Date: ${item.expiryDate.toString().split(' ')[0]}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.isExpired ? Colors.red : Colors.green.shade900))]),
        ),
        const Divider(height: 48),
        const Text('Suggested Local Recipes:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text(LocalRecipeService.getRecipeSuggestions(item.name), style: const TextStyle(fontSize: 15, height: 1.5))),
      ])),
    );
  }
  Widget _infoChip(IconData icon, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)]));
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
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.shopping_basket))),
      const SizedBox(height: 16),
      TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category))),
      const SizedBox(height: 16),
      TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number),
      const SizedBox(height: 16),
      ListTile(title: const Text('Expiry Date'), subtitle: Text('${_expiry.toLocal()}'.split(' ')[0]), trailing: const Icon(Icons.calendar_today), onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _expiry, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 3650)));
        if (d != null) setState(() => _expiry = d);
      }, tileColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, {'name': _name.text, 'category': _cat.text, 'quantity': int.tryParse(_qty.text) ?? 1, 'expiryDate': _expiry}), child: const Text('Add to Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
    ])));
  }
}

// --- NOTIFICATION SERVICE ---
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: initializationSettingsAndroid));
  }
  static Future<void> scheduleExpiryNotification(GroceryItem item) async {
    final alertDate = item.expiryDate.subtract(const Duration(days: 2));
    if (alertDate.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(item.id.hashCode, 'Almost Expired: ${item.name}', 'Use it soon!', tz.TZDateTime.from(alertDate, tz.local).add(const Duration(hours: 9)), const NotificationDetails(android: AndroidNotificationDetails('expiry_channel', 'Expiry Alerts', importance: Importance.max, priority: Priority.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    }
  }
  static Future<void> cancelNotifications(String id) async => await _notifications.cancel(id.hashCode);
}
