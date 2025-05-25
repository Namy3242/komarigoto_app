import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'presentation/ingredient_inventory_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // ダミー食材データ
  final Map<String, List<Ingredient>> _categorizedIngredients = {
    '野菜': [
      Ingredient(name: 'トマト', icon: Icons.local_pizza, category: '野菜', isAvailable: true),
      Ingredient(name: 'きゅうり', icon: Icons.eco, category: '野菜', isAvailable: false),
      Ingredient(name: 'にんじん', icon: Icons.emoji_nature, category: '野菜', isAvailable: true),
    ],
    '肉': [
      Ingredient(name: '鶏肉', icon: Icons.set_meal, category: '肉', isAvailable: true),
      Ingredient(name: '豚肉', icon: Icons.lunch_dining, category: '肉', isAvailable: false),
    ],
    '魚': [
      Ingredient(name: 'サーモン', icon: Icons.set_meal, category: '魚', isAvailable: false),
    ],
    '調味料': [
      Ingredient(name: '塩', icon: Icons.spa, category: '調味料', isAvailable: true),
      Ingredient(name: 'しょうゆ', icon: Icons.spa, category: '調味料', isAvailable: true),
    ],
    'その他': [
      Ingredient(name: '卵', icon: Icons.egg, category: 'その他', isAvailable: true),
    ],
  };

  void _toggleIngredient(Ingredient ingredient) {
    setState(() {
      ingredient.isAvailable = !ingredient.isAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: IngredientInventoryScreen(
        categorizedIngredients: _categorizedIngredients,
        onToggle: _toggleIngredient,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: '今ある食材で作れるレシピ',
        child: const Icon(Icons.restaurant_menu),
      ),
    );
  }
}
