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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(), _password = TextEditingController();
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
      await GoogleSignIn().signOut();
      final gs = await GoogleSignIn().signIn();
      final ga = await gs?.authentication;
      if (ga != null) {
        await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(accessToken: ga.accessToken, idToken: ga.idToken));
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

class GroceryItem {
  String name, category, id;
  int quantity;
  DateTime expiryDate, addedDate;
  String? imageUrl;

  GroceryItem({required this.name, required this.category, required this.quantity, required this.expiryDate, required this.addedDate, this.imageUrl, required this.id});

  Map<String, dynamic> toMap() => {
    'name': name, 'category': category, 'quantity': quantity, 'expiryDate': expiryDate.toIso8601String(), 'addedDate': addedDate.toIso8601String(), 'imageUrl': imageUrl
  };

  factory GroceryItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroceryItem(
      id: doc.id,
      name: d['name'],
      category: d['category'],
      quantity: d['quantity'] ?? 1,
      expiryDate: DateTime.parse(d['expiryDate']),
      addedDate: DateTime.parse(d['addedDate']),
      imageUrl: d['imageUrl']
    );
  }

  bool get isAlmostExpired => expiryDate.difference(DateTime.now()).inDays <= 3 && !isExpired;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
}

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static Stream<List<GroceryItem>> getItems() => _db.collection('users').doc(_uid).collection('inventory').snapshots().map((s) => s.docs.map((d) => GroceryItem.fromDoc(d)).toList());
  static Future<void> addItem(GroceryItem i) async => await _db.collection('users').doc(_uid).collection('inventory').add(i.toMap());
  static Future<void> updateItem(String id, Map<String, dynamic> data) async => await _db.collection('users').doc(_uid).collection('inventory').doc(id).update(data);
  static Future<void> deleteItem(String id) async => await _db.collection('users').doc(_uid).collection('inventory').doc(id).delete();

  static Future<void> completeItem(GroceryItem i) async {
    await _db.collection('users').doc(_uid).collection('stats').add({'name': i.name, 'date': DateTime.now().toIso8601String(), 'category': i.category, 'status': 'used', 'quantity': i.quantity});
    await deleteItem(i.id);
  }

  static Future<void> markAsWasted(GroceryItem i) async {
    await _db.collection('users').doc(_uid).collection('stats').add({'name': i.name, 'date': DateTime.now().toIso8601String(), 'category': i.category, 'status': 'wasted', 'quantity': i.quantity});
    await deleteItem(i.id);
  }

  static Stream<QuerySnapshot> getStats() => _db.collection('users').doc(_uid).collection('stats').snapshots();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final labeler = ImageLabelerService();
  String _cat = 'Total Items';

  @override void initState() {
    super.initState();
    labeler.initialize();
  }

  void _showLoading(String msg) => showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Text(msg)])));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green.shade50,
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StatsPage()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async { await GoogleSignIn().signOut(); await FirebaseAuth.instance.signOut(); }),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.green.shade50,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['Total Items', 'Almost Expired', 'Expired'].map((c) => InkWell(onTap: () => setState(() => _cat = c), child: Text(c, style: TextStyle(color: _cat == c ? Colors.green.shade800 : Colors.black54, fontWeight: _cat == c ? FontWeight.bold : FontWeight.normal)))).toList()),
        ),
        Expanded(child: StreamBuilder<List<GroceryItem>>(
          stream: FirebaseService.getItems(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = _cat == 'Almost Expired' ? snap.data!.where((i) => i.isAlmostExpired).toList() : _cat == 'Expired' ? snap.data!.where((i) => i.isExpired).toList() : snap.data!;
            if (items.isEmpty) return const Center(child: Text('Inventory is empty.'));
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) => Dismissible(
                key: Key(items[i].id),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (d) => FirebaseService.markAsWasted(items[i]),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: items[i].imageUrl != null && File(items[i].imageUrl!).existsSync()
                        ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(items[i].imageUrl!), width: 50, height: 50, fit: BoxFit.cover))
                        : const Icon(Icons.inventory_2, color: Colors.green, size: 40),
                    title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Qty: ${items[i].quantity} | ${items[i].category}'),
                        Text(items[i].isExpired ? 'Expired!' : 'Expires in ${items[i].expiryDate.difference(DateTime.now()).inDays} days', style: TextStyle(color: items[i].isExpired ? Colors.red : Colors.orange)),
                      ],
                    ),
                    trailing: IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green), onPressed: () => FirebaseService.completeItem(items[i])),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ItemDetailPage(item: items[i]))),
                  ),
                ),
              ),
            );
          },
        )),
      ]),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual',
            child: const Icon(Icons.edit, color: Colors.green),
            backgroundColor: Colors.white,
            onPressed: () async {
              final data = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (c) => const AddItemPage(initialName: '', initialCategory: '', suggestions: [], initialExpiry: null, isDateDetected: true)));
              if (data != null) {
                await FirebaseService.addItem(GroceryItem(id: '', name: data['name'], category: data['category'], quantity: data['quantity'], expiryDate: data['expiryDate'], addedDate: DateTime.now(), imageUrl: data['imageUrl']));
              }
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'scan',
            child: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
              if (photo == null) return;
              _showLoading('Analyzing...');
              final ocr = MlOcr();
              final labelData = await ocr.analyzeLabel(File(photo.path));
              final analysis = await labeler.analyzeImage(File(photo.path), labelData.itemName ?? "");
              ocr.dispose();
              Navigator.pop(context);
              final data = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (c) => AddItemPage(initialName: labelData.itemName ?? analysis.name, initialCategory: analysis.category, suggestions: analysis.suggestions, initialExpiry: labelData.expiryDate, isDateDetected: labelData.dateDetected, imageFile: File(photo.path))));
              if (data != null) {
                await FirebaseService.addItem(GroceryItem(id: '', name: data['name'], category: data['category'], quantity: data['quantity'], expiryDate: data['expiryDate'], addedDate: DateTime.now(), imageUrl: data['imageUrl']));
              }
            },
          ),
        ],
      ),
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sustainability Analyst')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getStats(),
        builder: (context, statsSnap) {
          return StreamBuilder<List<GroceryItem>>(
            stream: FirebaseService.getItems(),
            builder: (context, invSnap) {
              if (!statsSnap.hasData || !invSnap.hasData) return const Center(child: CircularProgressIndicator());
              final stats = statsSnap.data!.docs, inventory = invSnap.data!;
              final wasted = stats.where((d) => (d.data() as Map)['status'] == 'wasted').toList();
              final saved = stats.where((d) => (d.data() as Map)['status'] == 'used').toList();

              double totalSavedQty = 0;
              for (var d in saved) { totalSavedQty += (d.data() as Map)['quantity'] ?? 1; }
              double totalWastedQty = 0;
              for (var d in wasted) { totalWastedQty += (d.data() as Map)['quantity'] ?? 1; }

              int score = (totalSavedQty + totalWastedQty == 0) ? 100 : ((totalSavedQty / (totalSavedQty + totalWastedQty)) * 100).round();
              String risk = inventory.any((i) => i.isExpired) ? "High" : (inventory.any((i) => i.isAlmostExpired) ? "Medium" : "Low");

              Map<String, double> catWaste = {};
              for (var d in wasted) {
                String c = (d.data() as Map)['category'] ?? 'Others';
                double qty = ((d.data() as Map)['quantity'] ?? 1).toDouble();
                catWaste[c] = (catWaste[c] ?? 0) + qty;
              }
              if (catWaste.isEmpty) catWaste['No Waste'] = 1;

              // MONDAY START CALCULATION
              DateTime now = DateTime.now();
              DateTime lastMonday = now.subtract(Duration(days: now.weekday - 1));
              List<BarChartGroupData> barGroups = [];
              for (int i = 0; i < 7; i++) {
                DateTime dt = lastMonday.add(Duration(days: i));
                String dateStr = dt.toIso8601String().split('T')[0];
                double dayWasteQty = 0;
                for (var d in wasted) {
                  if ((d.data() as Map)['date'].toString().startsWith(dateStr)) {
                    dayWasteQty += (d.data() as Map)['quantity'] ?? 1;
                  }
                }
                barGroups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: dayWasteQty, color: Colors.redAccent, width: 15)]));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildReportCard(score, risk, totalWastedQty),
                  const SizedBox(height: 30),
                  const Text('Waste Distribution by Category (Qty)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 200, child: PieChart(PieChartData(sections: catWaste.entries.map((e) => PieChartSectionData(value: e.value, title: '${e.key}\n(${e.value.toInt()})', radius: 50, color: Colors.primaries[catWaste.keys.toList().indexOf(e.key) % Colors.primaries.length], titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))).toList()))),
                  const SizedBox(height: 30),
                  const Text('Weekly Food Waste Trend (Qty)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 250, child: BarChart(BarChartData(
                    barGroups: barGroups,
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][v.toInt() % 7], style: const TextStyle(fontSize: 10))))),
                    ),
                  ))),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(int score, String risk, double wastedQty) {
    return Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Waste Risk Level:', style: TextStyle(fontWeight: FontWeight.bold)), Text(risk, style: TextStyle(color: risk == "High" ? Colors.red : (risk == "Medium" ? Colors.orange : Colors.green), fontWeight: FontWeight.bold))]),
      const Divider(),
      Text('Sustainability Score: $score/100', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
      Text('Total Items Wasted: ${wastedQty.toInt()}', style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 10), const Text('Practical Suggestions:', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('• Use near-expiry vegetables in soups.\n• Freeze dairy products before expiry.\n• Plan meals weekly to reduce overbuying.'),
      const SizedBox(height: 15), Text(score > 70 ? "“Great job! You're making progress in saving the planet.”" : "“Focus on reducing waste to improve your score!”", style: const TextStyle(fontStyle: FontStyle.italic)),
    ])));
  }
}

class AddItemPage extends StatefulWidget {
  final String initialName, initialCategory;
  final List<String> suggestions;
  final DateTime? initialExpiry;
  final bool isDateDetected;
  final String? editId;
  final File? imageFile;

  const AddItemPage({super.key, required this.initialName, required this.initialCategory, required this.suggestions, this.initialExpiry, required this.isDateDetected, this.editId, this.imageFile});
  @override State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  late TextEditingController _name, _cat, _qty;
  late DateTime _expiry;
  String? _localPath;

  @override void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _cat = TextEditingController(text: widget.initialCategory);
    _qty = TextEditingController(text: '1');
    _expiry = widget.initialExpiry ?? DateTime.now().add(const Duration(days: 7));
    _localPath = widget.imageFile?.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editId != null ? 'Edit Item' : 'Add Item')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_localPath != null) Center(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_localPath!), height: 150, fit: BoxFit.cover))),
        const SizedBox(height: 15),
        if (!widget.isDateDetected) Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 10), Expanded(child: Text('Expiry date not detected. Set manually.', style: TextStyle(color: Colors.orange)))])) ,
        TextField(controller: _name, onChanged: (v) => setState(() {}), decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())), const SizedBox(height: 12),
        TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())), const SizedBox(height: 12),
        TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), keyboardType: TextInputType.number), const SizedBox(height: 12),
        ListTile(title: const Text('Expiry Date'), subtitle: Text(_expiry.toString().split(' ')[0]), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, initialDate: _expiry, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 3650))); if (d != null) setState(() => _expiry = d); }),
        const Divider(height: 40),
        const Text('Details & Suggestions (Preview):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text(LocalRecipeService.getRecipeSuggestions(_name.text), style: const TextStyle(fontSize: 14))),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, {'name': _name.text, 'category': _cat.text, 'quantity': int.tryParse(_qty.text) ?? 1, 'expiryDate': _expiry, 'imageUrl': _localPath}), child: Text(widget.editId != null ? 'Save Changes' : 'Add to Inventory')))
      ])),
    );
  }
}

class ItemDetailPage extends StatelessWidget {
  final GroceryItem item;
  const ItemDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name), actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () async {
          final data = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (c) => AddItemPage(initialName: item.name, initialCategory: item.category, suggestions: [], initialExpiry: item.expiryDate, isDateDetected: true, editId: item.id, imageFile: item.imageUrl != null ? File(item.imageUrl!) : null)));
          if (data != null) { await FirebaseService.updateItem(item.id, data); Navigator.pop(context); }
        }),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { FirebaseService.deleteItem(item.id); Navigator.pop(context); })
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.imageUrl != null && File(item.imageUrl!).existsSync()) Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(item.imageUrl!), height: 200, fit: BoxFit.cover))),
        const SizedBox(height: 20),
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
        const Text('Suggested Recipes:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(LocalRecipeService.getRecipeSuggestions(item.name), style: const TextStyle(fontSize: 16)),
      ])),
    );
  }
  Widget _infoChip(IconData icon, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)]));
}

class NotificationService {
  static final _n = FlutterLocalNotificationsPlugin();
  static Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _n.initialize(const InitializationSettings(android: initializationSettingsAndroid));
  }
  static Future<void> scheduleExpiryNotification(GroceryItem i) async {
    final alert = i.expiryDate.subtract(const Duration(days: 2));
    if (alert.isAfter(DateTime.now())) {
      await _n.zonedSchedule(i.id.hashCode, 'Expiring Soon', '${i.name} in 2 days', tz.TZDateTime.from(alert, tz.local).add(const Duration(hours: 9)), const NotificationDetails(android: AndroidNotificationDetails('exp', 'Exp')), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    }
  }
  static Future<void> cancelNotifications(String id) async => await _n.cancel(id.hashCode);
}
