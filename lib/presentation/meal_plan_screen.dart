import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

// 献立データのモデル
class MealPlan {
  final String id;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final String category; // '時短' or 'じっくり'
  final String status; // '未調理' or '調理済'
  final DateTime createdAt;
  final int mealNumber; // 1回目、2回目、3回目

  MealPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.mealNumber,
  });

  factory MealPlan.fromFirestore(String id, Map<String, dynamic> data) {
    return MealPlan(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      steps: List<String>.from(data['steps'] ?? []),
      category: data['category'] ?? '時短',
      status: data['status'] ?? '未調理',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mealNumber: data['mealNumber'] ?? 1,
    );
  }
}

// 献立プロバイダー
final mealPlansProvider = StreamProvider<List<MealPlan>>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  developer.log('MealPlansProvider: userId = $userId', name: 'MealPlanScreen');
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users/$userId/meal_plans')
      .snapshots()
      .map((snapshot) {
        developer.log('Firestore snapshot: ${snapshot.docs.length} documents', name: 'MealPlanScreen');
        final meals = snapshot.docs
            .map((doc) {
              final data = doc.data();
              developer.log('Document ${doc.id}: $data', name: 'MealPlanScreen');
              return MealPlan.fromFirestore(doc.id, data);
            })
            .toList();
        
        // クライアント側でソート
        meals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return meals;
      });
});

// 献立画面
class MealPlanScreen extends HookConsumerWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealPlansAsync = ref.watch(mealPlansProvider);
    final tabController = useTabController(initialLength: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('献立管理'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: '未調理'),
            Tab(text: '調理済'),
          ],
        ),
      ),
      body: mealPlansAsync.when(
        data: (mealPlans) {
          developer.log('Fetched ${mealPlans.length} meal plans', name: 'MealPlanScreen');
          for (final meal in mealPlans) {
            developer.log('Meal: ${meal.title}, Status: ${meal.status}, MealNumber: ${meal.mealNumber}', name: 'MealPlanScreen');
          }
          
          final uncooked = mealPlans.where((meal) => meal.status == '未調理').toList();
          final cooked = mealPlans.where((meal) => meal.status == '調理済').toList();
          
          developer.log('Uncooked: ${uncooked.length}, Cooked: ${cooked.length}', name: 'MealPlanScreen');

          return TabBarView(
            controller: tabController,
            children: [
              _buildMealPlanList(context, uncooked, '未調理', ref),
              _buildMealPlanList(context, cooked, '調理済', ref),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('エラーが発生しました: $error'),
        ),
      ),
    );
  }

  Widget _buildMealPlanList(BuildContext context, List<MealPlan> meals, String status, WidgetRef ref) {
    if (meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == '未調理' ? Icons.restaurant_menu : Icons.check_circle,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              status == '未調理' ? '未調理の献立がありません' : '調理済の献立がありません',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 献立セットでグループ化
    final mealSets = <DateTime, List<MealPlan>>{};
    for (final meal in meals) {
      final date = DateTime(meal.createdAt.year, meal.createdAt.month, meal.createdAt.day);
      mealSets[date] = (mealSets[date] ?? [])..add(meal);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mealSets.length,
      itemBuilder: (context, index) {
        final date = mealSets.keys.elementAt(index);
        final mealSet = mealSets[date]!;
        mealSet.sort((a, b) => a.mealNumber.compareTo(b.mealNumber));

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${date.month}/${date.day}の献立',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...mealSet.map((meal) => _buildMealPlanCard(context, meal, ref)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMealPlanCard(BuildContext context, MealPlan meal, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: meal.category == '時短' 
              ? Colors.orange.shade100 
              : Colors.blue.shade100,
          child: Text(
            '${meal.mealNumber}',
            style: TextStyle(
              color: meal.category == '時短' 
                  ? Colors.orange.shade700 
                  : Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          meal.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: meal.category == '時短' 
                        ? Colors.orange.shade100 
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    meal.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: meal.category == '時短' 
                          ? Colors.orange.shade700 
                          : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              meal.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: meal.status == '未調理'
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _markAsCooked(meal.id, ref),
                tooltip: '調理完了',
              )
            : Icon(Icons.check_circle, color: Colors.green),
        onTap: () => _showRecipeDetail(context, meal),
      ),
    );
  }

  void _showRecipeDetail(BuildContext context, MealPlan meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: meal.category == '時短' 
                          ? Colors.orange.shade100 
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      meal.category,
                      style: TextStyle(
                        color: meal.category == '時短' 
                            ? Colors.orange.shade700 
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                meal.description,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      '材料',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...meal.ingredients.map((ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6),
                          const SizedBox(width: 8),
                          Text(ingredient),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                    Text(
                      '作り方',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...meal.steps.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            child: Text('${entry.key + 1}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAsCooked(String mealId, WidgetRef ref) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users/$userId/meal_plans')
          .doc(mealId)
          .update({'status': '調理済'});

      developer.log('Meal marked as cooked: $mealId', name: 'MealPlanScreen');
    } catch (e) {
      developer.log('Failed to mark meal as cooked: $e', name: 'MealPlanScreen');
    }
  }
}
