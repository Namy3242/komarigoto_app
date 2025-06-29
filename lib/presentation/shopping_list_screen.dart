import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

// 買い物リストアイテムの状態管理
final shoppingListProvider = StreamProvider<List<ShoppingListItem>>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (userId.isEmpty) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('users/$userId/shopping_list')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ShoppingListItem.fromFirestore(doc))
          .toList());
});

// 買い物リストアイテムのデータクラス
class ShoppingListItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final bool isPurchased;
  final DateTime addedAt;
  final String? memo;

  ShoppingListItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.isPurchased,
    required this.addedAt,
    this.memo,
  });

  factory ShoppingListItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingListItem(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'その他',
      quantity: data['quantity'] ?? 1,
      unit: data['unit'] ?? '個',
      isPurchased: data['isPurchased'] ?? false,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memo: data['memo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'isPurchased': isPurchased,
      'addedAt': Timestamp.fromDate(addedAt),
      'memo': memo,
    };
  }

  ShoppingListItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    String? unit,
    bool? isPurchased,
    DateTime? addedAt,
    String? memo,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isPurchased: isPurchased ?? this.isPurchased,
      addedAt: addedAt ?? this.addedAt,
      memo: memo ?? this.memo,
    );
  }
}

class ShoppingListScreen extends HookConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shoppingListAsync = ref.watch(shoppingListProvider);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物リスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: '購入済みを削除',
            onPressed: () => _clearPurchasedItems(context, userId),
          ),
        ],
      ),
      body: shoppingListAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '買い物リストは空です',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '調理画面から在庫外レシピを生成すると\n必要な材料がここに追加されます',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // カテゴリごとにグループ化
          final groupedItems = <String, List<ShoppingListItem>>{};
          for (final item in items) {
            groupedItems.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 統計情報
              _buildStatisticsCard(items),
              const SizedBox(height: 16),
              
              // カテゴリごとのアイテム表示
              ...groupedItems.entries.map((entry) {
                return _buildCategorySection(context, entry.key, entry.value, userId);
              }).toList(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('エラーが発生しました: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(context, userId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatisticsCard(List<ShoppingListItem> items) {
    final totalItems = items.length;
    final purchasedItems = items.where((item) => item.isPurchased).length;
    final remainingItems = totalItems - purchasedItems;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('合計', totalItems.toString(), Icons.list),
            _buildStatItem('完了', purchasedItems.toString(), Icons.check_circle),
            _buildStatItem('残り', remainingItems.toString(), Icons.pending),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<ShoppingListItem> items,
    String userId,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...items.map((item) => _buildShoppingListItem(context, item, userId)),
        ],
      ),
    );
  }

  Widget _buildShoppingListItem(
    BuildContext context,
    ShoppingListItem item,
    String userId,
  ) {
    return CheckboxListTile(
      value: item.isPurchased,
      onChanged: (value) => _togglePurchased(item, value ?? false, userId),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.isPurchased ? TextDecoration.lineThrough : null,
          color: item.isPurchased ? Colors.grey : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.quantity} ${item.unit}'),
          if (item.memo != null && item.memo!.isNotEmpty)
            Text(
              item.memo!,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      secondary: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _showEditItemDialog(context, item, userId);
              break;
            case 'delete':
              _deleteItem(item, userId);
              break;
            case 'amazon':
              _openShoppingUrl(item.name, 'amazon');
              break;
            case 'rakuten':
              _openShoppingUrl(item.name, 'rakuten');
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('編集'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('削除'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'amazon',
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.orange),
                SizedBox(width: 8),
                Text('Amazonで検索'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'rakuten',
            child: Row(
              children: [
                Icon(Icons.shopping_bag, color: Colors.red),
                SizedBox(width: 8),
                Text('楽天で検索'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePurchased(ShoppingListItem item, bool isPurchased, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users/$userId/shopping_list')
          .doc(item.id)
          .update({'isPurchased': isPurchased});
    } catch (e) {
      developer.log('Failed to toggle purchased status: $e');
    }
  }

  Future<void> _deleteItem(ShoppingListItem item, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users/$userId/shopping_list')
          .doc(item.id)
          .delete();
    } catch (e) {
      developer.log('Failed to delete item: $e');
    }
  }

  Future<void> _clearPurchasedItems(BuildContext context, String userId) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('購入済みアイテムを削除'),
        content: const Text('購入済みのアイテムをすべて削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users/$userId/shopping_list')
            .where('isPurchased', isEqualTo: true)
            .get();

        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      } catch (e) {
        developer.log('Failed to clear purchased items: $e');
      }
    }
  }

  Future<void> _openShoppingUrl(String itemName, String platform) async {
    String url;
    switch (platform) {
      case 'amazon':
        url = 'https://www.amazon.co.jp/s?k=${Uri.encodeComponent(itemName)}';
        break;
      case 'rakuten':
        url = 'https://search.rakuten.co.jp/search/mall/${Uri.encodeComponent(itemName)}';
        break;
      default:
        return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAddItemDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AddShoppingItemDialog(userId: userId),
    );
  }

  void _showEditItemDialog(BuildContext context, ShoppingListItem item, String userId) {
    showDialog(
      context: context,
      builder: (context) => AddShoppingItemDialog(
        userId: userId,
        editingItem: item,
      ),
    );
  }
}

class AddShoppingItemDialog extends HookWidget {
  final String userId;
  final ShoppingListItem? editingItem;

  const AddShoppingItemDialog({
    super.key,
    required this.userId,
    this.editingItem,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: editingItem?.name ?? '');
    final quantityController = useTextEditingController(
      text: editingItem?.quantity.toString() ?? '1',
    );
    final memoController = useTextEditingController(text: editingItem?.memo ?? '');
    final selectedCategory = useState(editingItem?.category ?? '野菜');
    final selectedUnit = useState(editingItem?.unit ?? '個');

    final categories = ['野菜', '肉・魚・卵', '調味料', '主食', 'その他'];
    final units = ['個', 'パック', 'kg', 'g', 'L', 'ml', '本', '袋'];

    return AlertDialog(
      title: Text(editingItem == null ? 'アイテム追加' : 'アイテム編集'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '商品名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit.value,
                    decoration: const InputDecoration(
                      labelText: '単位',
                      border: OutlineInputBorder(),
                    ),
                    items: units.map((unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    )).toList(),
                    onChanged: (value) => selectedUnit.value = value!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory.value,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                border: OutlineInputBorder(),
              ),
              items: categories.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              )).toList(),
              onChanged: (value) => selectedCategory.value = value!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: memoController,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => _saveItem(context, nameController, quantityController,
              memoController, selectedCategory.value, selectedUnit.value),
          child: Text(editingItem == null ? '追加' : '更新'),
        ),
      ],
    );
  }

  Future<void> _saveItem(
    BuildContext context,
    TextEditingController nameController,
    TextEditingController quantityController,
    TextEditingController memoController,
    String category,
    String unit,
  ) async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品名を入力してください')),
      );
      return;
    }

    try {
      final data = {
        'name': nameController.text.trim(),
        'category': category,
        'quantity': int.tryParse(quantityController.text) ?? 1,
        'unit': unit,
        'isPurchased': editingItem?.isPurchased ?? false,
        'addedAt': editingItem?.addedAt != null 
            ? Timestamp.fromDate(editingItem!.addedAt)
            : FieldValue.serverTimestamp(),
        'memo': memoController.text.trim().isEmpty ? null : memoController.text.trim(),
      };

      if (editingItem == null) {
        await FirebaseFirestore.instance
            .collection('users/$userId/shopping_list')
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('users/$userId/shopping_list')
            .doc(editingItem!.id)
            .update(data);
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(editingItem == null ? 'アイテムを追加しました' : 'アイテムを更新しました'),
          ),
        );
      }
    } catch (e) {
      developer.log('Failed to save item: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました')),
        );
      }
    }
  }
}
