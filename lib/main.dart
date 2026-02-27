import 'dart:io';
import 'dart:ui';
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

// --- NOTIFICATION SERVICE ---
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: initializationSettingsAndroid));
    _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  static Future<void> scheduleExpiryNotification(GroceryItem item) async {
    final now = DateTime.now();

    // FOR TESTING: Set alert to exactly 1 minute from this second
    final alertDate = now.add(const Duration(minutes: 1));

    if (alertDate.isAfter(now)) {
      await _notifications.zonedSchedule(
        item.id.hashCode,
        'GrocerKu: Waste Alert! 🥗',
        'Testing: This is your 1-minute alert for ${item.name}!',
        tz.TZDateTime.from(alertDate, tz.local), // Use alertDate directly
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_channel',
            'Expiry Alerts',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
  // static Future<void> scheduleExpiryNotification(GroceryItem item) async {
  //   final now = DateTime.now();
  //   final alertDate = item.expiryDate.subtract(const Duration(minutes: 1));
  //   if (alertDate.isAfter(now)) {
  //     await _notifications.zonedSchedule(
  //       item.id.hashCode,
  //       'GrocerKu: Waste Alert! 🥗',
  //       'Your ${item.name} is expiring in 2 days. Use it now to save food!',
  //       tz.TZDateTime.from(alertDate, tz.local).add(const Duration(hours: 9)),
  //       const NotificationDetails(android: AndroidNotificationDetails('expiry_channel', 'Expiry Alerts', importance: Importance.max, priority: Priority.high)),
  //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //       uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  //     );
  //   }
  // }

  static Future<void> cancelNotifications(String id) async => await _notifications.cancel(id.hashCode);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { debugPrint("Firebase init failed: $e"); }
  await NotificationService.init();
  runApp(const KitaHackApp());
}

class KitaHackApp extends StatelessWidget {
  const KitaHackApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrocerKu with KitaHack 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, primary: Colors.green.shade800),
        useMaterial3: true,
        cardTheme: CardThemeData(elevation: 4, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return (snapshot.hasData && snapshot.data != null) ? const HomePage() : const LoginPage();
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
      if (_isLogin) { await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim()); }
      else { await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text.trim()); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _googleSignIn() async {
    try {
      await GoogleSignIn().signOut();
      final gs = await GoogleSignIn().signIn();
      final ga = await gs?.authentication;
      if (ga != null) { await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(accessToken: ga.accessToken, idToken: ga.idToken)); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.green.shade100, Colors.white, Colors.green.shade50]))),
          Center(child: SingleChildScrollView(padding: const EdgeInsets.all(30.0), child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.5))),
                child: Column(children: [
                  const Icon(Icons.eco_rounded, size: 80, color: Colors.green),
                  const SizedBox(height: 10),
                  const Text('GrocerKu', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                  const Text('with KitaHack 2026', style: TextStyle(color: Colors.black54, letterSpacing: 1.2)),
                  const SizedBox(height: 40),
                  TextField(controller: _email, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
                  const SizedBox(height: 25),
                  SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: Text(_isLogin ? 'Login' : 'Join GrocerKu'))),
                  TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? 'New here? Create Account' : 'Already have an account?')),
                  const Divider(height: 40),
                  SizedBox(width: double.infinity, height: 55, child: OutlinedButton.icon(icon: const Icon(Icons.login), label: const Text('Sign in with Google'), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _googleSignIn)),
                ]),
              ),
            ),
          ))),
        ],
      ),
    );
  }
}

class GroceryItem {
  String name, category, id; int quantity; DateTime expiryDate, addedDate; String? imageUrl;
  GroceryItem({required this.name, required this.category, required this.quantity, required this.expiryDate, required this.addedDate, this.imageUrl, required this.id});
  Map<String, dynamic> toMap() => {'name': name, 'category': category, 'quantity': quantity, 'expiryDate': expiryDate.toIso8601String(), 'addedDate': addedDate.toIso8601String(), 'imageUrl': imageUrl};
  factory GroceryItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroceryItem(id: doc.id, name: d['name'], category: d['category'], quantity: d['quantity'] ?? 1, expiryDate: DateTime.parse(d['expiryDate']), addedDate: DateTime.parse(d['addedDate']), imageUrl: d['imageUrl']);
  }
  bool get isAlmostExpired => expiryDate.difference(DateTime.now()).inDays <= 3 && !isExpired;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
}

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static Stream<List<GroceryItem>> getItems() => _db.collection('users').doc(_uid).collection('inventory').snapshots().map((s) => s.docs.map((d) => GroceryItem.fromDoc(d)).toList());
  static Future<void> addItem(GroceryItem i) async {
    final doc = await _db.collection('users').doc(_uid).collection('inventory').add(i.toMap());
    NotificationService.scheduleExpiryNotification(GroceryItem(id: doc.id, name: i.name, category: i.category, quantity: i.quantity, expiryDate: i.expiryDate, addedDate: i.addedDate, imageUrl: i.imageUrl));
  }
  static Future<void> updateItem(String id, Map<String, dynamic> data) async => await _db.collection('users').doc(_uid).collection('inventory').doc(id).update(data);
  static Future<void> deleteItem(String id) async {
    await NotificationService.cancelNotifications(id);
    await _db.collection('users').doc(_uid).collection('inventory').doc(id).delete();
  }
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
  int _currentIndex = 0;
  @override void initState() { super.initState(); labeler.initialize(); }
  
  void _confirmDelete(GroceryItem i) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Remove Item'),
      content: const Text('Was this item an incorrect entry, or was it wasted?'),
      actions: [
        TextButton(onPressed: () { FirebaseService.deleteItem(i.id); Navigator.pop(c); }, child: const Text('Incorrect Entry', style: TextStyle(color: Colors.black54))),
        ElevatedButton(onPressed: () { FirebaseService.markAsWasted(i); Navigator.pop(c); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Food Waste', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GrocerKu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), centerTitle: true, elevation: 0, backgroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.bar_chart_rounded, color: Colors.green), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StatsPage()))),
        IconButton(icon: const Icon(Icons.logout), onPressed: () async { await GoogleSignIn().signOut(); await FirebaseAuth.instance.signOut(); }),
      ]),
      body: Stack(children: [
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)]))),
        Positioned(bottom: 50, right: -30, child: Opacity(opacity: 0.03, child: Icon(Icons.shopping_basket, size: 250, color: Colors.green))),
        StreamBuilder<List<GroceryItem>>(stream: FirebaseService.getItems(), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = _currentIndex == 1 ? snap.data!.where((i) => i.isAlmostExpired).toList() : _currentIndex == 2 ? snap.data!.where((i) => i.isExpired).toList() : snap.data!;
          if (items.isEmpty) return const Center(child: Text('Inventory is clear!'));
          return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: items.length, itemBuilder: (c, i) => _buildCard(items[i]));
        }),
      ]),
      floatingActionButton: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton.small(heroTag: 'man', child: const Icon(Icons.edit), backgroundColor: Colors.orange, onPressed: () => _openAdd(null)),
        const SizedBox(height: 12),
        FloatingActionButton(heroTag: 'scn', child: const Icon(Icons.qr_code_scanner), backgroundColor: Colors.green, onPressed: _scanItem),
      ]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _currentIndex, selectedItemColor: Colors.green.shade800, onTap: (idx) => setState(() => _currentIndex = idx), items: const [
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Fridge'),
        BottomNavigationBarItem(icon: Icon(Icons.timer_outlined), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.error_outline), label: 'Expired'),
      ]),
    );
  }

  Widget _buildCard(GroceryItem i) {
    return Dismissible(key: Key(i.id), confirmDismiss: (d) async { _confirmDelete(i); return false; }, background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)), child: Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
      leading: i.imageUrl != null && File(i.imageUrl!).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(i.imageUrl!), width: 55, height: 55, fit: BoxFit.cover)) : CircleAvatar(backgroundColor: Colors.green.shade100, child: const Icon(Icons.fastfood, color: Colors.green)),
      title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${i.category} • Qty: ${i.quantity}\n${i.isExpired ? "Expired" : "Expires in ${i.expiryDate.difference(DateTime.now()).inDays} days"}', style: TextStyle(color: i.isExpired ? Colors.red : Colors.black54)),
      trailing: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 28), onPressed: () => FirebaseService.completeItem(i)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ItemDetailPage(item: i))),
    )));
  }

  void _openAdd(GroceryItem? i) async {
    final data = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (c) => AddItemPage(initialName: i?.name ?? '', initialCategory: i?.category ?? 'Vegetables', suggestions: [], initialExpiry: i?.expiryDate, isDateDetected: true)));
    if (data != null) await FirebaseService.addItem(GroceryItem(id: '', name: data['name'], category: data['category'], quantity: data['quantity'], expiryDate: data['expiryDate'], addedDate: DateTime.now(), imageUrl: data['imageUrl']));
  }

  void _scanItem() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1000, imageQuality: 85);
    if (photo == null) return;
    final ocr = MlOcr(); final ld = await ocr.analyzeLabel(File(photo.path));
    final ans = await labeler.analyzeImage(File(photo.path), ld.itemName ?? ""); ocr.dispose();
    final data = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (c) => AddItemPage(initialName: ld.itemName ?? ans.name, initialCategory: ans.category, suggestions: ans.suggestions, initialExpiry: ld.expiryDate, isDateDetected: ld.dateDetected, imageFile: File(photo.path))));
    if (data != null) await FirebaseService.addItem(GroceryItem(id: '', name: data['name'], category: data['category'], quantity: data['quantity'], expiryDate: data['expiryDate'], addedDate: DateTime.now(), imageUrl: data['imageUrl']));
  }
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impact Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getStats(),
        builder: (context, statsSnap) {
          return StreamBuilder<List<GroceryItem>>(
            stream: FirebaseService.getItems(),
            builder: (context, invSnap) {
              if (!statsSnap.hasData || !invSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = statsSnap.data!.docs;
              final inventory = invSnap.data!;

              final wasted = stats
                  .where((d) => (d.data() as Map)['status'] == 'wasted')
                  .toList();

              final used = stats
                  .where((d) => (d.data() as Map)['status'] == 'used')
                  .toList();

              final currentExpired =
              inventory.where((i) => i.isExpired).toList();

              double totalWasted = 0;
              for (var d in wasted) {
                totalWasted += (d.data() as Map)['quantity'] ?? 1;
              }

              double totalUsed = 0;
              for (var d in used) {
                totalUsed += (d.data() as Map)['quantity'] ?? 1;
              }

              double expiredInFridge = 0;
              for (var i in currentExpired) {
                expiredInFridge += i.quantity;
              }

              double totalItems =
                  totalUsed + totalWasted + expiredInFridge;

              int wasteRate = (totalItems == 0)
                  ? 0
                  : (((totalWasted + expiredInFridge) / totalItems) * 100)
                  .round();

              Map<String, double> catWaste = {};

              for (var d in wasted) {
                String c =
                    (d.data() as Map)['category'] ?? 'Others';
                catWaste[c] =
                    (catWaste[c] ?? 0) +
                        ((d.data() as Map)['quantity'] ?? 1);
              }

              for (var i in currentExpired) {
                catWaste[i.category] =
                    (catWaste[i.category] ?? 0) + i.quantity;
              }

              DateTime now = DateTime.now();
              DateTime lastMon =
              now.subtract(Duration(days: now.weekday - 1));

              List<BarChartGroupData> bars =
              List.generate(7, (i) {
                String dStr = lastMon
                    .add(Duration(days: i))
                    .toIso8601String()
                    .split('T')[0];

                double qty = 0;
                for (var d in wasted) {
                  if ((d.data() as Map)['date']
                      .toString()
                      .startsWith(dStr)) {
                    qty +=
                        (d.data() as Map)['quantity'] ?? 1;
                  }
                }

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: qty,
                      color: Colors.green.shade700,
                      width: 16,
                      borderRadius:
                      BorderRadius.circular(4),
                    )
                  ],
                );
              });

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.green.shade50,
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding:
                          const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text(
                                'Overall Waste Rate',
                                style: TextStyle(
                                    fontWeight:
                                    FontWeight.bold),
                              ),
                              Text(
                                '$wasteRate%',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight:
                                  FontWeight.bold,
                                  color: wasteRate > 20
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                              const Text(
                                'Includes wasted and current expired items.',
                                style: TextStyle(
                                  color:
                                  Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Categories Wasted (Quantity)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      if (catWaste.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: catWaste.entries
                                  .map(
                                    (e) =>
                                    PieChartSectionData(
                                      value: e.value,
                                      title:
                                      '${e.key}\n(${e.value.toInt()})',
                                      radius: 60,
                                      color: Colors.primaries[
                                      catWaste.keys
                                          .toList()
                                          .indexOf(
                                          e.key) %
                                          Colors
                                              .primaries
                                              .length],
                                      titleStyle:
                                      const TextStyle(
                                        fontSize: 10,
                                        color:
                                        Colors.white,
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                      ),
                                    ),
                              )
                                  .toList(),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding:
                          EdgeInsets.all(20),
                          child: Text(
                            'Great! No waste data yet.',
                          ),
                        ),
                      const SizedBox(height: 30),
                      const Text(
                        'Weekly Waste Trend (Monday Start)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            barGroups: bars,
                            borderData:
                            FlBorderData(show: false),
                            gridData:
                            const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles:
                              const AxisTitles(
                                sideTitles:
                                SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                ),
                              ),
                              bottomTitles:
                              AxisTitles(
                                sideTitles:
                                SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (v, m) => Text(
                                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][v.toInt() % 7],
                                  ),
                                ),
                              ),
                              topTitles:
                              const AxisTitles(),
                              rightTitles:
                              const AxisTitles(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AddItemPage extends StatefulWidget {
  final String initialName, initialCategory; final List<String> suggestions; final DateTime? initialExpiry; final bool isDateDetected; final File? imageFile;
  const AddItemPage({super.key, required this.initialName, required this.initialCategory, required this.suggestions, this.initialExpiry, required this.isDateDetected, this.imageFile});
  @override State<AddItemPage> createState() => _AddItemPageState();
}
class _AddItemPageState extends State<AddItemPage> {
  late TextEditingController _name, _qty; String _cat = 'Vegetables'; late DateTime _expiry;
  final List<String> _cats = ['Fruits', 'Vegetables', 'Meat & Seafood', 'Dry/Wet Food', 'Others'];
  @override void initState() { super.initState(); _name = TextEditingController(text: widget.initialName); _qty = TextEditingController(text: '1'); _cat = _cats.contains(widget.initialCategory) ? widget.initialCategory : 'Vegetables'; _expiry = widget.initialExpiry ?? DateTime.now().add(const Duration(days: 7)); }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Grocery')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.imageFile != null) Center(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(widget.imageFile!, height: 150, fit: BoxFit.cover))),
        const SizedBox(height: 20),
        TextField(controller: _name, onChanged: (v) => setState(() {}), decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder())),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(value: _cat, decoration: const InputDecoration(labelText: 'Category (Compulsory)', border: OutlineInputBorder()), items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _cat = v!)),
        const SizedBox(height: 15),
        TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 15),
        ListTile(title: const Text('Expiry Date'), subtitle: Text(_expiry.toString().split(' ')[0]), trailing: const Icon(Icons.calendar_today), tileColor: Colors.grey.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), onTap: () async { final d = await showDatePicker(context: context, initialDate: _expiry, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 3650))); if (d != null) setState(() => _expiry = d); }),
        const Divider(height: 40),
        const Text('Recipes Preview:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade100)), child: Text(LocalRecipeService.getRecipeSuggestions(_name.text), style: const TextStyle(fontSize: 13))),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, height: 55, child: FilledButton(onPressed: () => Navigator.pop(context, {'name': _name.text, 'category': _cat, 'quantity': int.tryParse(_qty.text) ?? 1, 'expiryDate': _expiry, 'imageUrl': widget.imageFile?.path}), child: const Text('Save to GrocerKu')))
      ])),
    );
  }
}

class ItemDetailPage extends StatelessWidget {
  final GroceryItem item; const ItemDetailPage({super.key, required this.item});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name), actions: [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { FirebaseService.deleteItem(item.id); Navigator.pop(context); })]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.imageUrl != null && File(item.imageUrl!).existsSync()) Center(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(item.imageUrl!), height: 220, fit: BoxFit.cover))),
        const SizedBox(height: 20),
        Row(children: [ _badge(Icons.category, item.category), const SizedBox(width: 10), _badge(Icons.numbers, 'Qty: ${item.quantity}') ]),
        const SizedBox(height: 15),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: item.isExpired ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.event, color: item.isExpired ? Colors.red : Colors.green), const SizedBox(width: 12), Text('Expiry Date: ${item.expiryDate.toString().split(' ')[0]}', style: TextStyle(fontWeight: FontWeight.bold, color: item.isExpired ? Colors.red : Colors.green.shade900))])),
        const Divider(height: 50),
        const Text('Recipe Suggestions:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 10),
        Text(LocalRecipeService.getRecipeSuggestions(item.name), style: const TextStyle(fontSize: 15, height: 1.6)),
      ])),
    );
  }
  Widget _badge(IconData i, String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)), child: Row(children: [Icon(i, size: 16, color: Colors.green), const SizedBox(width: 6), Text(t, style: const TextStyle(fontWeight: FontWeight.bold))]));
}
