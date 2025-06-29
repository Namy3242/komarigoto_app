import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'auth_service.dart';
import 'ingredient_inventory_screen.dart';

// --- 気分レシピ画面 ---
class MoodRecipeScreen extends HookConsumerWidget {
  const MoodRecipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // ローカルでローディング状態を管理
    final isLoading = useState(false);
    final notifier = ref.read(ingredientInventoryProvider.notifier);
    
    // --- 選択肢 ---
    final cookingMethods = [
      '焼く', '蒸す', '茹でる', '煮る', '揚げる', '炒める', '和える', '炊く', '漬ける', 'オーブン', '電子レンジ'
    ];
    final cuisines = [
      '和風', '洋風', '中華', 'イタリアン', 'フレンチ', 'エスニック', '韓国', '北欧', 'ジャンク', 'アジアン', 'アメリカン', 'スパイスカレー',
    ];
    final preferences = [
      '時短', '味重視', 'ヘルシー', '節約', 'ボリューム', '見た目重視', '作り置き', '簡単'
    ];
    // --- State ---
    final selectedMethods = useState<List<String>>([]);
    final selectedCuisines = useState<List<String>>([]);
    final selectedPreferences = useState<List<String>>([]);
    final freewordController = useTextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ストレスフリーに食卓を！'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                final authService = AuthService();
                await authService.signOut();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('調理法', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: cookingMethods.map((m) => ChoiceChip(
                  label: Text(m),
                  selected: selectedMethods.value.contains(m),
                  onSelected: (v) {
                    final list = [...selectedMethods.value];
                    if (v) {
                      if (!list.contains(m)) list.add(m);
                    } else {
                      list.remove(m);
                    }
                    selectedMethods.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('料理ジャンル', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: cuisines.map((c) => ChoiceChip(
                  label: Text(c),
                  selected: selectedCuisines.value.contains(c),
                  onSelected: (v) {
                    final list = [...selectedCuisines.value];
                    if (v) {
                      if (!list.contains(c)) list.add(c);
                    } else {
                      list.remove(c);
                    }
                    selectedCuisines.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('こだわり', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: preferences.map((p) => ChoiceChip(
                  label: Text(p),
                  selected: selectedPreferences.value.contains(p),
                  onSelected: (v) {
                    final list = [...selectedPreferences.value];
                    if (v) {
                      if (!list.contains(p)) list.add(p);
                    } else {
                      list.remove(p);
                    }
                    selectedPreferences.value = list;
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('フリーワード', style: theme.textTheme.titleMedium),
              TextField(
                controller: freewordController,
                decoration: const InputDecoration(
                  hintText: '例: 辛い、あっさり、おしゃれ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              // 在庫ありレシピと在庫外レシピの説明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '在庫ありレシピ',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '現在の冷蔵庫にある食材で作れるレシピを生成します',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          '在庫外レシピ',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '新しい食材を使ったレシピを生成し、必要な材料を買い物リストに追加します',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('選択した条件でレシピを提案します。', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 在庫外レシピ生成ボタン
          FloatingActionButton.extended(
            onPressed: isLoading.value
                ? null
                : () async {
                    final method = selectedMethods.value.join(' ');
                    final cuisine = selectedCuisines.value.join(' ');
                    final pref = selectedPreferences.value.join(' ');
                    final freeword = freewordController.text.trim();
                    final extra = [method, cuisine, pref, freeword].where((e) => e.isNotEmpty).join(' ');
                    
                    // ローディング開始
                    isLoading.value = true;
                    try {
                      await _generateExternalRecipe(context, extra, ref);
                    } finally {
                      // ローディング終了
                      isLoading.value = false;
                    }
                  },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            icon: isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.shopping_cart),
            label: const Text('在庫外レシピ'),
            heroTag: 'external_recipe',
          ),
          const SizedBox(height: 16),
          // 在庫ありレシピ生成ボタン
          FloatingActionButton.extended(
            onPressed: isLoading.value
                ? null
                : () async {
                    final method = selectedMethods.value.join(' ');
                    final cuisine = selectedCuisines.value.join(' ');
                    final pref = selectedPreferences.value.join(' ');
                    final freeword = freewordController.text.trim();
                    final extra = [method, cuisine, pref, freeword].where((e) => e.isNotEmpty).join(' ');
                    
                    // ローディング開始
                    isLoading.value = true;
                    try {
                      await notifier.suggestAndSaveRecipes(context, '気分', extra);
                    } finally {
                      // ローディング終了
                      isLoading.value = false;
                    }
                  },
            icon: isLoading.value
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : const Icon(Icons.restaurant),
            label: const Text('在庫ありレシピ'),
            heroTag: 'stock_recipe',
          ),
        ],
      ),
    );
  }

  // 在庫外レシピ生成メソッド
  Future<void> _generateExternalRecipe(BuildContext context, String extra, WidgetRef ref) async {
    const endpoint = 'https://asia-northeast2-komarigoto-app.cloudfunctions.net/recipe_suggest';
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    
    try {
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey ?? '',
        },
        body: jsonEncode({
          'ingredients': [], // 在庫を使わない
          'mealType': '気分',
          'extraCondition': '$extra 在庫にない新しい食材を使って',
          'generateExternal': true, // 在庫外フラグ
        }),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final recipes = data['recipes'] as List<dynamic>?;
        if (recipes == null || recipes.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('レシピが見つかりませんでした。')),
            );
          }
          return;
        }
        
        // レシピを保存
        await _saveExternalRecipes(recipes, ref);
        
        // 材料を買い物リストに追加
        await _addIngredientsToShoppingList(recipes, ref);
        
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('在庫外レシピ生成完了'),
              content: const Text('新しいレシピを生成し、必要な材料を買い物リストに追加しました。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // 買い物リスト画面に移動 - MainBottomNavは元のファイルにあるため、直接画面遷移は行わない
                    // 代わりにSnackBarで案内
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('買い物リストタブで材料を確認してください'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: const Text('買い物リストを見る'),
                ),
              ],
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('レシピ生成APIの呼び出しに失敗しました。\n${res.body}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通信エラー: $e')),
        );
      }
    }
  }

  // 在庫外レシピをFirestoreに保存
  Future<void> _saveExternalRecipes(List<dynamic> recipes, WidgetRef ref) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) return;
      
      final batch = FirebaseFirestore.instance.batch();
      final recipesCol = FirebaseFirestore.instance.collection('users/$userId/recipes');
      
      for (final recipe in recipes) {
        final data = {
          'title': recipe['title'] ?? '',
          'description': recipe['description'] ?? '',
          'ingredients': recipe['ingredients'] ?? [],
          'steps': recipe['steps'] ?? [],
          'titleImageUrl': '',
          'stepImageUrls': [],
          'createdAt': FieldValue.serverTimestamp(),
          'isExternal': true, // 在庫外レシピフラグ
        };
        batch.set(recipesCol.doc(), data);
      }
      await batch.commit();
      developer.log('External recipes saved to Firestore successfully', name: 'MoodRecipeScreen');
    } catch (e) {
      developer.log('Failed to save external recipes to Firestore: $e', name: 'MoodRecipeScreen');
    }
  }

  // 材料を買い物リストに追加
  Future<void> _addIngredientsToShoppingList(List<dynamic> recipes, WidgetRef ref) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) return;
      
      final batch = FirebaseFirestore.instance.batch();
      final shoppingListCol = FirebaseFirestore.instance.collection('users/$userId/shopping_list');
      
      // 既存の買い物リストを取得
      final existingItems = await shoppingListCol.get();
      final existingNames = existingItems.docs
          .map((doc) => doc.data()['name'] as String)
          .toSet();
      
      // 在庫にある食材を取得
      final inventoryState = ref.read(ingredientInventoryProvider);
      final stockIngredients = inventoryState.values
          .expand((list) => list)
          .where((item) => item.isAvailable)
          .map((item) => item.name)
          .toList();
      
      for (final recipe in recipes) {
        final recipeIngredients = (recipe['ingredients'] as List<dynamic>? ?? []).cast<String>();
        
        // バックエンドAPIで必要な材料を判定（量や単位を除去済み）
        final neededIngredients = await _judgeNeededIngredients(recipeIngredients, stockIngredients);
        
        for (final ingredient in neededIngredients) {
          // 買い物リストにもない材料のみ追加
          if (!existingNames.contains(ingredient)) {
            final data = {
              'name': ingredient,
              'category': _categorizeIngredient(ingredient),
              'quantity': 1,
              'unit': '個',
              'isPurchased': false,
              'addedAt': FieldValue.serverTimestamp(),
              'memo': 'レシピから自動追加',
            };
            batch.set(shoppingListCol.doc(), data);
            existingNames.add(ingredient); // 重複防止
          }
        }
      }
      
      await batch.commit();
      developer.log('Ingredients added to shopping list successfully', name: 'MoodRecipeScreen');
    } catch (e) {
      developer.log('Failed to add ingredients to shopping list: $e', name: 'MoodRecipeScreen');
    }
  }

  // 基本的な材料かどうかを判定（調味料や一般的な材料）
  bool _isBasicIngredient(String ingredient) {
    final basicIngredients = {
      '塩', '砂糖', '醤油', 'みそ', '酢', '油', 'サラダ油', 'ごま油', 'オリーブオイル',
      '水', '湯', 'こしょう', '胡椒', 'にんにく', '生姜', '玉ねぎ', '卵', 'ご飯', 'パン',
      '小麦粉', '片栗粉', '酒', 'みりん', 'だし', 'コンソメ', '鶏がらスープの素',
    };
    
    return basicIngredients.any((basic) => 
        ingredient.contains(basic) || basic.contains(ingredient));
  }

  // 材料名からカテゴリを推定
  String _categorizeIngredient(String ingredient) {
    if (ingredient.contains('肉') || ingredient.contains('牛') || ingredient.contains('豚') || 
        ingredient.contains('鶏') || ingredient.contains('魚') || ingredient.contains('エビ') ||
        ingredient.contains('イカ') || ingredient.contains('タコ')) {
      return '肉・魚・卵';
    } else if (ingredient.contains('野菜') || ingredient.contains('キャベツ') || 
               ingredient.contains('人参') || ingredient.contains('大根') || 
               ingredient.contains('ほうれん草') || ingredient.contains('レタス')) {
      return '野菜';
    } else if (ingredient.contains('米') || ingredient.contains('パン') || 
               ingredient.contains('麺') || ingredient.contains('パスタ')) {
      return '主食';
    } else if (ingredient.contains('調味料') || ingredient.contains('ソース') || 
               ingredient.contains('ドレッシング') || ingredient.contains('スパイス')) {
      return '調味料';
    } else {
      return 'その他';
    }
  }

  // Gemini APIで必要な材料を判定する
  Future<List<String>> _judgeNeededIngredients(List<String> recipeIngredients, List<String> stockIngredients) async {
    try {
      const endpoint = 'https://asia-northeast2-komarigoto-app.cloudfunctions.net/judge_ingredients';
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey ?? '',
        },
        body: jsonEncode({
          'recipe_ingredients': recipeIngredients,
          'stock_ingredients': stockIngredients,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final neededIngredients = (data['needed_ingredients'] as List<dynamic>?)
            ?.cast<String>() ?? [];
        
        developer.log('Gemini API判定結果: ${neededIngredients.length}個の材料が必要', 
                     name: 'MoodRecipeScreen');
        return neededIngredients;
      } else {
        developer.log('材料判定API呼び出し失敗: ${response.statusCode}', 
                     name: 'MoodRecipeScreen');
        // エラー時はローカル判定にフォールバック
        return _fallbackJudgeIngredients(recipeIngredients, stockIngredients);
      }
    } catch (e) {
      developer.log('材料判定でエラー: $e', name: 'MoodRecipeScreen');
      // エラー時はローカル判定にフォールバック
      return _fallbackJudgeIngredients(recipeIngredients, stockIngredients);
    }
  }

  // フォールバック用のローカル判定
  List<String> _fallbackJudgeIngredients(List<String> recipeIngredients, List<String> stockIngredients) {
    final inStockNames = stockIngredients.toSet();
    return recipeIngredients.where((ingredient) {
      // 在庫にない且つ基本的な材料でない場合に必要と判定
      return !inStockNames.contains(ingredient) && !_isBasicIngredient(ingredient);
    }).toList();
  }
}
