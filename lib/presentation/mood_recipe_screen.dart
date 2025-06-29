import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'auth_service.dart';
import 'recipe_generation_screen.dart';

// --- 気分レシピ画面 ---
class MoodRecipeScreen extends HookConsumerWidget {
  const MoodRecipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // ローカルでローディング状態を管理
    final isLoading = useState(false);
    
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading.value
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeGenerationScreen(
                      selectedMethods: selectedMethods.value,
                      selectedCuisines: selectedCuisines.value,
                      selectedPreferences: selectedPreferences.value,
                      freeword: freewordController.text.trim(),
                    ),
                  ),
                );
              },
        icon: isLoading.value
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : const Icon(Icons.restaurant_menu),
        label: const Text('レシピ生成'),
      ),
    );
  }
}
