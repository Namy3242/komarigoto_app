import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class IngredientMasterAddScreen extends StatefulWidget {
  const IngredientMasterAddScreen({Key? key}) : super(key: key);

  @override
  State<IngredientMasterAddScreen> createState() => _IngredientMasterAddScreenState();
}

class _IngredientMasterAddScreenState extends State<IngredientMasterAddScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _category = '主食';

  final List<String> _categories = [
    '主食', '肉・魚・卵・豆', '野菜', 'きのこ', '調味料', 'その他'
  ];

  // Firestoreのingredients_master一覧を取得
  Stream<QuerySnapshot<Map<String, dynamic>>> get _ingredientStream =>
      FirebaseFirestore.instance.collection('ingredients_master').orderBy('category').snapshots();

  Future<void> _addIngredient() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    log('[addIngredient] Firestoreに食材追加: name=$_name, category=$_category');
    await FirebaseFirestore.instance.collection('ingredients_master').add({
      'name': _name,
      'category': _category,
      // Cloud Functionsで自動生成するためimageUrl/kana/synonymsは空値で初期化
      'imageUrl': '',
      'kana': '',
      'synonyms': <String>[],
    }).then((docRef) {
      log('[addIngredient] Firestore追加完了: docId=[32m[1m[4m[0m[39m[22m[24m${docRef.id}');
    }).catchError((e) {
      log('[addIngredient] Firestore追加エラー: $e', level: 1000);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('食材を登録しました')));
      _formKey.currentState!.reset();
      setState(() {
        _category = '主食';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マスタ食材追加')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: '食材名'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '必須項目です';
                      if (v.length > 20) return '20文字以内で入力してください';
                      return null;
                    },
                    onSaved: (v) => _name = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _category,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v ?? '主食'),
                    decoration: const InputDecoration(labelText: 'カテゴリ'),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      onPressed: _addIngredient,
                      child: const Text('登録'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const Text('登録済み食材一覧', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _ingredientStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('まだ登録がありません'));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final docId = docs[i].id;
                      return Dismissible(
                        key: ValueKey(docId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('削除確認'),
                              content: Text('「${data['name']}」をマスタから削除しますか？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('キャンセル')),
                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await FirebaseFirestore.instance.collection('ingredients_master').doc(docId).delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${data['name']} をマスタから削除しました')),
                          );
                        },
                        child: ListTile(
                          leading: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                              ? Image.network(data['imageUrl'], width: 36, height: 36, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                              : const Icon(Icons.fastfood),
                          title: Text(data['name'] ?? ''),
                          subtitle: Text(data['category'] ?? ''),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
