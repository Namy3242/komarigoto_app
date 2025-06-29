import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'firebase_options.dart';
import 'presentation/auth_service.dart';
import 'presentation/ingredient_inventory_screen.dart';
import 'presentation/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load();
  runApp(
    ProviderScope(child: MyApp()), // RiverpodのProviderScopeでラップ
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ストレスフリーに食卓を！',
      theme: ThemeData(
        // 美味しそうなオレンジ系の色で統一
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35), // 食欲をそそるオレンジ
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // AppBarのテーマを統一
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6B35), // メインのオレンジ色
          foregroundColor: Colors.white, // 白いテキスト
          elevation: 2,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: StreamBuilder(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const MainBottomNav();
          } else {
            return const SignInScreen();
          }
        },
      ),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const IngredientInventoryScreen(), // categorizedIngredients渡しを廃止
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: '今ある食材で作れるレシピ',
        child: const Icon(Icons.restaurant_menu),
      ),
    );
  }
}
