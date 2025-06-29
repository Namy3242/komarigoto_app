import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'ingredient_inventory_screen.dart';

class RecipeGenerationScreen extends HookConsumerWidget {
  final List<String> selectedMethods;
  final List<String> selectedCuisines;
  final List<String> selectedPreferences;
  final String freeword;

  const RecipeGenerationScreen({
    super.key,
    required this.selectedMethods,
    required this.selectedCuisines,
    required this.selectedPreferences,
    required this.freeword,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = useState(false);

    // 条件文字列を構築
    final extra = [
      selectedMethods.join(' '),
      selectedCuisines.join(' '),
      selectedPreferences.join(' '),
      freeword,
    ].where((e) => e.isNotEmpty).join(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ生成方法'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 選択した条件の表示
            if (extra.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '選択した条件',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      extra,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 在庫ありレシピ
            Card(
              child: InkWell(
                onTap: isLoading.value
                    ? null
                    : () async {
                        isLoading.value = true;
                        try {
                          final notifier = ref.read(ingredientInventoryProvider.notifier);
                          await notifier.suggestAndSaveRecipes(context, '気分', extra);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } finally {
                          isLoading.value = false;
                        }
                      },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '在庫ありレシピ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '現在の冷蔵庫にある食材で作れるレシピを生成します',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 在庫外レシピ
            Card(
              child: InkWell(
                onTap: isLoading.value
                    ? null
                    : () async {
                        isLoading.value = true;
                        try {
                          await _generateExternalRecipe(context, extra, ref);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } finally {
                          isLoading.value = false;
                        }
                      },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: 48,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '在庫外レシピ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '新しい食材を使ったレシピを生成し、必要な材料を買い物リストに追加します',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 献立生成
            Card(
              child: InkWell(
                onTap: isLoading.value
                    ? null
                    : () => _showMealPlanDialog(context, extra, ref, isLoading),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_view_week,
                        size: 48,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '献立生成',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1〜3回分の献立を生成します\n時短レシピとじっくりレシピの組み合わせが選べます',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ローディング表示
            if (isLoading.value)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('レシピを生成中...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMealPlanDialog(BuildContext context, String extra, WidgetRef ref, ValueNotifier<bool> isLoading) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('献立生成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('何回分の献立を生成しますか？'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMealCountButton(context, 1, extra, ref, isLoading),
                _buildMealCountButton(context, 2, extra, ref, isLoading),
                _buildMealCountButton(context, 3, extra, ref, isLoading),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCountButton(BuildContext context, int count, String extra, WidgetRef ref, ValueNotifier<bool> isLoading) {
    return ElevatedButton(
      onPressed: () async {
        Navigator.pop(context); // ダイアログを閉じる
        isLoading.value = true;
        try {
          await _generateMealPlan(context, extra, ref, count);
          if (context.mounted) {
            Navigator.pop(context); // RecipeGenerationScreenを閉じる
          }
        } finally {
          isLoading.value = false;
        }
      },
      child: Text('${count}回分'),
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
      developer.log('External recipes saved to Firestore successfully', name: 'RecipeGenerationScreen');
    } catch (e) {
      developer.log('Failed to save external recipes to Firestore: $e', name: 'RecipeGenerationScreen');
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
      developer.log('Ingredients added to shopping list successfully', name: 'RecipeGenerationScreen');
    } catch (e) {
      developer.log('Failed to add ingredients to shopping list: $e', name: 'RecipeGenerationScreen');
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
                     name: 'RecipeGenerationScreen');
        return neededIngredients;
      } else {
        developer.log('材料判定API呼び出し失敗: ${response.statusCode}', 
                     name: 'RecipeGenerationScreen');
        // エラー時はローカル判定にフォールバック
        return _fallbackJudgeIngredients(recipeIngredients, stockIngredients);
      }
    } catch (e) {
      developer.log('材料判定でエラー: $e', name: 'RecipeGenerationScreen');
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

  // 献立生成メソッド（回数指定版）
  Future<void> _generateMealPlan(BuildContext context, String extra, WidgetRef ref, int mealCount) async {
    const endpoint = 'https://asia-northeast2-komarigoto-app.cloudfunctions.net/recipe_suggest';
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    
    try {
      // 在庫にある食材を取得
      final inventoryState = ref.read(ingredientInventoryProvider);
      final stockIngredients = inventoryState.values
          .expand((list) => list)
          .where((item) => item.isAvailable)
          .map((item) => item.name)
          .toList();

      final allMealPlanRecipes = <Map<String, dynamic>>[];

      // 時短レシピとじっくりレシピの組み合わせを決定
      int quickCount = 0;
      int slowCount = 0;
      
      if (mealCount == 1) {
        // 1回分：時短1つ
        quickCount = 1;
        slowCount = 0;
      } else if (mealCount == 2) {
        // 2回分：時短1つ、じっくり1つ
        quickCount = 1;
        slowCount = 1;
      } else {
        // 3回分：時短2つ、じっくり1つ
        quickCount = 2;
        slowCount = 1;
      }

      // 時短レシピを生成
      for (int i = 0; i < quickCount; i++) {
        final res = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-API-KEY': apiKey ?? '',
          },
          body: jsonEncode({
            'ingredients': stockIngredients,
            'mealType': '気分',
            'extraCondition': '$extra 時短 簡単 30分以内',
            'generateExternal': false,
          }),
        );
        
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final recipes = data['recipes'] as List<dynamic>?;
          if (recipes != null && recipes.isNotEmpty) {
            final recipe = recipes.first as Map<String, dynamic>;
            recipe['category'] = '時短';
            recipe['mealNumber'] = i + 1;
            allMealPlanRecipes.add(recipe);
          }
        }
      }

      // じっくりレシピを生成
      for (int i = 0; i < slowCount; i++) {
        final res = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-API-KEY': apiKey ?? '',
          },
          body: jsonEncode({
            'ingredients': stockIngredients,
            'mealType': '気分',
            'extraCondition': '$extra じっくり 本格的 手作り',
            'generateExternal': false,
          }),
        );
        
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final recipes = data['recipes'] as List<dynamic>?;
          if (recipes != null && recipes.isNotEmpty) {
            final recipe = recipes.first as Map<String, dynamic>;
            recipe['category'] = 'じっくり';
            recipe['mealNumber'] = quickCount + i + 1;
            allMealPlanRecipes.add(recipe);
          }
        }
      }
      
      if (allMealPlanRecipes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('献立が生成できませんでした。')),
          );
        }
        return;
      }

      // 献立をFirestoreに保存
      await _saveMealPlan(allMealPlanRecipes, ref);
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('献立生成完了'),
            content: Text('${allMealPlanRecipes.length}つの献立を生成しました。\n時短レシピ${quickCount}つ、じっくりレシピ${slowCount}つです。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('献立生成でエラーが発生しました: $e')),
        );
      }
    }
  }

  // 献立をFirestoreに保存
  Future<void> _saveMealPlan(List<Map<String, dynamic>> recipes, WidgetRef ref) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) return;
      
      final batch = FirebaseFirestore.instance.batch();
      final mealPlansCol = FirebaseFirestore.instance.collection('users/$userId/meal_plans');
      
      for (final recipe in recipes) {
        final data = {
          'title': recipe['title'] ?? '',
          'description': recipe['description'] ?? '',
          'ingredients': recipe['ingredients'] ?? [],
          'steps': recipe['steps'] ?? [],
          'category': recipe['category'] ?? '時短', // '時短' or 'じっくり'
          'status': '未調理', // '未調理' or '調理済'
          'mealNumber': recipe['mealNumber'] ?? 1, // 1, 2, 3
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(mealPlansCol.doc(), data);
      }
      await batch.commit();
      developer.log('Meal plan saved to Firestore successfully', name: 'RecipeGenerationScreen');
    } catch (e) {
      developer.log('Failed to save meal plan to Firestore: $e', name: 'RecipeGenerationScreen');
    }
  }
}
