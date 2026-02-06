import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/ml_ocr.dart';
import 'services/image_labeler.dart';


// Main entry point of the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitaHackApp());
}

// Root widget of the application
class KitaHackApp extends StatelessWidget {
  const KitaHackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Smart Grocery & Food Waste Reduction App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- DATA MODELS ---
class GroceryItem {
  String name;
  String category;
  int quantity;
  DateTime expiryDate;
  final DateTime addedDate;
  final File? image;
  final String id;

  GroceryItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.expiryDate,
    required this.addedDate,
    this.image,
  }) : id = UniqueKey().toString();

  bool get isAlmostExpired => expiryDate.difference(DateTime.now()).inDays <= 3 && !isExpired;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
}

class Recipe {
  final String name;
  final String cookingTime;
  final List<String> ingredients;
  final List<String> instructions;
  final String id;

  Recipe({
    required this.name,
    required this.cookingTime,
    required this.ingredients,
    required this.instructions,
  }) : id = UniqueKey().toString();
}

// --- HOME PAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  String _selectedCategory = 'Total Items';

  // Data stores
  final List<GroceryItem> _allItems = [
    GroceryItem(name: 'Organic Bananas', category: 'Fruit', quantity: 5, expiryDate: DateTime.now().add(const Duration(days: 2)), addedDate: DateTime.now()),
    GroceryItem(name: 'Fresh Milk', category: 'Dairy', quantity: 1, expiryDate: DateTime.now().add(const Duration(days: 5)), addedDate: DateTime.now().subtract(const Duration(days: 1))),
    GroceryItem(name: 'Avocado', category: 'Fruit', quantity: 3, expiryDate: DateTime.now().add(const Duration(days: 1)), addedDate: DateTime.now()),
    GroceryItem(name: 'Apple', category: 'Fruit', quantity: 4, expiryDate: DateTime.now().add(const Duration(days: 10)), addedDate: DateTime.now()),
    GroceryItem(name: 'Flour', category: 'Pantry', quantity: 1, expiryDate: DateTime.now().add(const Duration(days: 365)), addedDate: DateTime.now()),
  ];

  final List<Recipe> _savedRecipes = [
    Recipe(
        name: 'Classic Apple Pie',
        cookingTime: '1 hour',
        ingredients: ['Apple', 'Flour', 'Sugar', 'Butter', 'Cinnamon'],
        instructions: [
          '1. Preheat oven to 425°F (220°C).',
          '2. Mix flour and sugar for the crust.',
          '3. Peel, core, and slice apples.',
          '4. Mix apples with sugar and cinnamon.',
          '5. Assemble the pie and bake for 45-55 minutes.'
        ]),
  ];

  // --- Core Logic Methods ---

  Future<void> _generateAndSaveRecipes() async {
    _showLoadingDialog('Generating Recipes with AI...');

    final List<Recipe> suggestedRecipes = await _simulateRecipeGeneration();
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

    final newRecipe = await showDialog<Recipe>(
        context: context, builder: (context) => RecipeSuggestionDialog(suggestedRecipes: suggestedRecipes));

    if (newRecipe != null) {
      setState(() {
        _savedRecipes.add(newRecipe);
      });
    }
  }

  Future<List<Recipe>> _simulateRecipeGeneration() async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      Recipe(
          name: 'Avocado Banana Smoothie',
          cookingTime: '5 minutes',
          ingredients: ['Avocado', 'Organic Bananas', 'Fresh Milk'],
          instructions: ['1. Combine all ingredients in a blender.', '2. Blend until smooth.', '3. Serve immediately.'])
    ];
  }

  // --- AI / Camera Scan Logic ---

  Future<void> _openCameraAndAddNewItem() async {
    try {
      // Pick image from camera
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null || !mounted) return;

      _showLoadingDialog('Analyzing Image with AI...');

      // Initialize AI services
      final mlOcr = MlOcr();
      final labeler = ImageLabelerService();

      // Extract text (for expiry date)
      final text = await mlOcr.extractText(File(photo.path));

      // Label image (detect item)
      final labels = await labeler.labelImage(File(photo.path));

      // Parse expiry date
      DateTime expiryDate = parseExpiryDate(text) ?? DateTime.now().add(const Duration(days: 7));

      // Map label to category
      final category = mapLabelsToCategory(labels);

      // Dispose services to free memory
      mlOcr.dispose();
      labeler.dispose();

      // Prepare AI result safely
      final Map<String, String> aiResult = {
        'name': labels.isNotEmpty ? labels.first : 'Unknown Item',
        'category': category,
        'expiryDate': expiryDate.toIso8601String(),
      };

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Navigate to AddItemPage with AI result
      final newItem = await Navigator.push<GroceryItem>(
        context,
        MaterialPageRoute(
          builder: (context) => AddItemPage(
            initialName: aiResult['name']!,
            initialCategory: aiResult['category']!,
            imageFile: File(photo.path),
          ),
        ),
      );

      // Save the new item if returned
      if (newItem != null) {
        setState(() {
          _allItems.insert(0, newItem);
          _selectedCategory = 'Total Items';
        });
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI scan failed: $e')),
      );
    }
  }

// --- Helper: Parse expiry date from OCR text ---
  DateTime? parseExpiryDate(String text) {
    final regex = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
    final match = regex.firstMatch(text);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }
    return null;
  }

// --- Helper: Map AI labels to categories ---
  String mapLabelsToCategory(List<String> labels) {
    if (labels.isEmpty) return 'Other';
    final label = labels.first.toLowerCase();

    // Improved mapping: more comprehensive
    const fruit = ['apple', 'banana', 'avocado', 'orange', 'mango', 'grape'];
    const dairy = ['milk', 'cheese', 'eggs', 'yogurt', 'butter'];
    const pantry = ['flour', 'rice', 'bread', 'sugar', 'salt', 'oil'];

    if (fruit.contains(label)) return 'Fruit';
    if (dairy.contains(label)) return 'Dairy';
    if (pantry.contains(label)) return 'Pantry';
    return 'Other';
  }




  Future<Map<String, String>> _simulateAiAnalysis() async {
    await Future.delayed(const Duration(seconds: 2));
    final List<Map<String, String>> possibleItems = [
      {'name': 'Apple', 'category': 'Fruit'},
      {'name': 'Tomato', 'category': 'Vegetable'},
      {'name': 'Carton of Eggs', 'category': 'Dairy & Eggs'},
      {'name': 'Broccoli', 'category': 'Vegetable'},
    ];
    return possibleItems[Random().nextInt(possibleItems.length)];
  }

  void _showLoadingDialog(String message) {
    showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
            content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Text(message)])));
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  void _navigateToDetail(GroceryItem item) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailPage(item: item)));
    if (result == null) return;
    if (result['action'] == 'deleted') {
      setState(() => _allItems.removeWhere((i) => i.id == item.id));
    } else if (result['action'] == 'updated') {
      setState(() {
        final index = _allItems.indexWhere((i) => i.id == item.id);
        if (index != -1) _allItems[index] = result['item'];
      });
    }
  }

  void _navigateToRecipeDetail(Recipe recipe) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeDetailPage(recipe: recipe, allItems: _allItems)),
    );

    if (result != null && result['action'] == 'completed') {
      setState(() {
        // Remove the recipe
        _savedRecipes.removeWhere((r) => r.id == recipe.id);

        // Deduct ingredients
        final ownedItemNames = _allItems.map((item) => item.name.toLowerCase()).toSet();
        final usedIngredients = recipe.ingredients.where((ing) => ownedItemNames.contains(ing.toLowerCase()));

        for (final ingredientName in usedIngredients) {
          final itemIndex = _allItems.indexWhere((item) => item.name.toLowerCase() == ingredientName.toLowerCase());
          if (itemIndex != -1) {
            _allItems[itemIndex].quantity--;
          }
        }

        // Remove items with zero quantity
        _allItems.removeWhere((item) => item.quantity <= 0);
      });
    }
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Smart Grocery & Food Waste Reduction App')),
      body: Column(children: [
        _buildTopActionBar(),
        if (_selectedCategory != 'Recipe Suggest')
          _buildItemView()
        else
          _buildRecipeView(),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCameraAndAddNewItem,
        tooltip: 'Scan New Item',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildItemView() {
    final filteredItems = _getFilteredAndSortedItems();
    return Expanded(
      child: Column(
        children: [
          _buildContentHeader(filteredItems.length),
          Expanded(child: _buildContentArea(filteredItems)),
        ],
      ),
    );
  }

  Widget _buildRecipeView() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: _generateAndSaveRecipes,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Recipes with AI'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
          _buildContentHeader(_savedRecipes.length, title: 'Saved Recipes'),
          Expanded(child: _buildRecipeList()),
        ],
      ),
    );
  }

  Widget _buildRecipeList() {
    if (_savedRecipes.isEmpty) {
      return const Center(child: Text('No saved recipes yet. Generate some with AI!'));
    }
    return ListView.builder(itemCount: _savedRecipes.length, itemBuilder: (context, index) {
      final recipe = _savedRecipes[index];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0), elevation: 2,
        child: ListTile(title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('Cooking time: ${recipe.cookingTime}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: () => _navigateToRecipeDetail(recipe)),
      );
    });
  }
  
  List<GroceryItem> _getFilteredAndSortedItems() {
    List<GroceryItem> filteredList;
    switch (_selectedCategory) {
      case 'Recently Added': filteredList = _allItems.where((item) => item.addedDate.difference(DateTime.now()).inDays.abs() <= 2).toList(); break;
      case 'Almost Expired': filteredList = _allItems.where((item) => item.isAlmostExpired).toList(); break;
      case 'Expired': filteredList = _allItems.where((item) => item.isExpired).toList(); break;
      default: filteredList = _allItems.toList();
    }
    filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filteredList;
  }
  Widget _buildTopActionBar() {
    const categories = ['Total Items', 'Recently Added', 'Almost Expired', 'Expired', 'Recipe Suggest'];
    return Container(height: 60, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: categories.map((category) {
        final isSelected = _selectedCategory == category;
        return Expanded(
          child: InkWell(onTap: () => _selectCategory(category), child: Container(alignment: Alignment.center,
              decoration: BoxDecoration(border: isSelected ? const Border(bottom: BorderSide(color: Colors.green, width: 3)) : null),
              child: Text(category, textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.green : Colors.black54)))),
        );
      }).toList()),
    );
  }
  Widget _buildContentHeader(int count, {String? title}) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(children: [Text(title ?? '$_selectedCategory ($count)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]),
    );
  }
  Widget _buildContentArea(List<GroceryItem> items) {
    if (items.isEmpty) return const Center(child: Text('No items in this category.'));
    return ListView.builder(itemCount: items.length, itemBuilder: (context, index) {
      final item = items[index];
      final daysRemaining = item.expiryDate.difference(DateTime.now()).inDays;
      return Card(margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0), elevation: 2,
        child: ListTile(leading: CircleAvatar(backgroundColor: item.isExpired ? Colors.red : item.isAlmostExpired ? Colors.orange : Colors.green,
            child: Text(daysRemaining.isNegative ? '!' : daysRemaining.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(item.isExpired ? 'Expired ${-daysRemaining} day(s) ago' : 'Expires in $daysRemaining day(s)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: () => _navigateToDetail(item)));
    });
  }
}


// --- RECIPE SUGGESTION DIALOG ---
class RecipeSuggestionDialog extends StatelessWidget {
  final List<Recipe> suggestedRecipes;
  const RecipeSuggestionDialog({super.key, required this.suggestedRecipes});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI Recipe Suggestions'),
      content: SizedBox(width: double.maxFinite,
        child: ListView.builder(shrinkWrap: true, itemCount: suggestedRecipes.length, itemBuilder: (context, index) {
            final recipe = suggestedRecipes[index];
            return ListTile(title: Text(recipe.name), trailing: FilledButton(onPressed: () => Navigator.of(context).pop(recipe), child: const Text('Add')));
          },),),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

// --- RECIPE DETAIL PAGE ---
class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;
  final List<GroceryItem> allItems;

  const RecipeDetailPage({super.key, required this.recipe, required this.allItems});

  void _showDoneConfirmationDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Complete Recipe?'),
        content: const Text('This will remove the recipe from your saved list and deduct the used ingredients from your inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            Navigator.of(ctx).pop(); // Close dialog
            Navigator.of(context).pop({'action': 'completed'}); // Pop detail page with completed action
          }, child: const Text('Complete')),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final ownedItemNames = allItems.map((item) => item.name.toLowerCase()).toSet();
    final ownedIngredients = recipe.ingredients.where((ing) => ownedItemNames.contains(ing.toLowerCase())).toList();
    final missingIngredients = recipe.ingredients.where((ing) => !ownedItemNames.contains(ing.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cooking Time: ${recipe.cookingTime}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              _buildSectionHeader('Ingredients'),
              if (ownedIngredients.isNotEmpty) ...[
                _buildIngredientSubHeader('You Have:'),
                ...ownedIngredients.map((e) => _buildIngredientTile(e, have: true)),
              ],
              if (missingIngredients.isNotEmpty) ...[
                _buildIngredientSubHeader('You Need:'),
                ...missingIngredients.map((e) => _buildIngredientTile(e, have: false)),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader('Instructions'),
              ...recipe.instructions.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('${e.key + 1}. ${e.value}'),
                  )),
            ])),
          ),
          // DONE BUTTON AREA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.done_all),
              label: const Text('Done'),
              onPressed: () => _showDoneConfirmationDialog(context),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  Widget _buildIngredientSubHeader(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)));
  Widget _buildIngredientTile(String name, {required bool have}) => ListTile(
        dense: true,
        leading: Icon(have ? Icons.check_box : Icons.check_box_outline_blank, color: have ? Colors.green : Colors.grey),
        title: Text(name),
      );
}

// --- OTHER PAGES (RESTORED) ---

class ItemDetailPage extends StatefulWidget {final GroceryItem item; const ItemDetailPage({super.key, required this.item}); @override State<ItemDetailPage> createState() => _ItemDetailPageState();}
class _ItemDetailPageState extends State<ItemDetailPage> { late GroceryItem currentItem; @override void initState() { super.initState(); currentItem = widget.item;} String _getExpiryStatus(GroceryItem item) { if (item.isExpired) return 'Expired'; if (item.isAlmostExpired) return 'Expires Soon'; return 'Fresh';} void _showDeleteConfirmationDialog() { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Item?'), content: Text('Are you sure you want to delete "${currentItem.name}"?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')), FilledButton(onPressed: () {Navigator.of(ctx).pop(); Navigator.of(context).pop({'action': 'deleted'});}, style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('Delete'))]));} void _navigateToEditPage() async { final updatedItem = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditItemPage(item: currentItem))); if (updatedItem != null) setState(() => currentItem = updatedItem);} @override Widget build(BuildContext context) { return WillPopScope(onWillPop: () async { Navigator.of(context).pop({'action': 'updated', 'item': currentItem}); return false;}, child: Scaffold(appBar: AppBar(title: Text(currentItem.name)), body: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 24), Text('Item Details', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const Divider(height: 24), _buildDetailRow('Name', currentItem.name), _buildDetailRow('Category', currentItem.category), _buildDetailRow('Quantity', currentItem.quantity.toString()), _buildDetailRow('Date Added', '${currentItem.addedDate.toLocal()}'.split(' ')[0]), _buildDetailRow('Expiry Date', '${currentItem.expiryDate.toLocal()}'.split(' ')[0]), _buildDetailRow('Status', _getExpiryStatus(currentItem)), const SizedBox(height: 32), SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.delete_forever), label: const Text('Delete Item'), onPressed: _showDeleteConfirmationDialog, style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 12))))])), floatingActionButton: FloatingActionButton(onPressed: _navigateToEditPage, tooltip: 'Edit Item', child: const Icon(Icons.edit))));} Widget _buildDetailRow(String label, String value) { return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 16)))]));}}
class EditItemPage extends StatefulWidget {final GroceryItem item; const EditItemPage({super.key, required this.item}); @override State<EditItemPage> createState() => _EditItemPageState();}
class _EditItemPageState extends State<EditItemPage> { final _formKey = GlobalKey<FormState>(); late TextEditingController _nameController, _categoryController, _quantityController; late DateTime _expiryDate; @override void initState() { super.initState(); _nameController = TextEditingController(text: widget.item.name); _categoryController = TextEditingController(text: widget.item.category); _quantityController = TextEditingController(text: widget.item.quantity.toString()); _expiryDate = widget.item.expiryDate;} Future<void> _selectDate() async { final picked = await showDatePicker(context: context, initialDate: _expiryDate, firstDate: DateTime(2000), lastDate: DateTime(2101)); if (picked != null && picked != _expiryDate) setState(() => _expiryDate = picked);} void _saveForm() { if (_formKey.currentState!.validate()) { widget.item.name = _nameController.text; widget.item.category = _categoryController.text; widget.item.quantity = int.tryParse(_quantityController.text) ?? 1; widget.item.expiryDate = _expiryDate; Navigator.of(context).pop(widget.item);}} @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('Edit Item'), actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveForm, tooltip: 'Save Changes')]), body: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Please enter a name' : null), const SizedBox(height: 16), TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Please enter a category' : null), const SizedBox(height: 16), TextFormField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v!) == null ? 'Please enter a valid number' : null), const SizedBox(height: 24), Row(children: [Expanded(child: Text('Expires on: ${_expiryDate.toLocal()}'.split(' ')[0], style: const TextStyle(fontSize: 16))), ElevatedButton.icon(onPressed: _selectDate, icon: const Icon(Icons.calendar_today), label: const Text('Change Date'))])]))));}}
class AddItemPage extends StatefulWidget {final String initialName; final String initialCategory; final File imageFile; const AddItemPage({super.key, required this.initialName, required this.initialCategory, required this.imageFile}); @override State<AddItemPage> createState() => _AddItemPageState();}
class _AddItemPageState extends State<AddItemPage> { final _formKey = GlobalKey<FormState>(); late TextEditingController _nameController, _categoryController, _quantityController; late DateTime _expiryDate; @override void initState() { super.initState(); _nameController = TextEditingController(text: widget.initialName); _categoryController = TextEditingController(text: widget.initialCategory); _quantityController = TextEditingController(text: '1'); _expiryDate = DateTime.now().add(const Duration(days: 7));} Future<void> _selectDate() async { final picked = await showDatePicker(context: context, initialDate: _expiryDate, firstDate: DateTime.now(), lastDate: DateTime(2101)); if (picked != null && picked != _expiryDate) setState(() => _expiryDate = picked);} void _saveForm() { if (_formKey.currentState!.validate()) { final newItem = GroceryItem(name: _nameController.text, category: _categoryController.text, quantity: int.tryParse(_quantityController.text) ?? 1, expiryDate: _expiryDate, addedDate: DateTime.now(), image: widget.imageFile); Navigator.of(context).pop(newItem);}} @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('Add New Item'), actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveForm, tooltip: 'Save Item')]), body: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Image.file(widget.imageFile, height: 200, width: double.infinity, fit: BoxFit.cover)), const SizedBox(height: 24), TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Please enter a name' : null), const SizedBox(height: 16), TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Please enter a category' : null), const SizedBox(height: 16), TextFormField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => int.tryParse(v!) == null ? 'Please enter a valid number' : null), const SizedBox(height: 24), Row(children: [Expanded(child: Text('Expires on: ${_expiryDate.toLocal()}'.split(' ')[0], style: const TextStyle(fontSize: 16))), ElevatedButton.icon(onPressed: _selectDate, icon: const Icon(Icons.calendar_today), label: const Text('Change Date'))]), const SizedBox(height: 32), SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Add Item to Inventory'), onPressed: _saveForm, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12))))]))));}}
