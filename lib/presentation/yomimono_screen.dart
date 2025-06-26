import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class YomimonoScreen extends StatelessWidget {
  const YomimonoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('よみもの'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const YomimonoContent(),
    );
  }
}

class YomimonoContent extends StatefulWidget {
  const YomimonoContent({super.key});

  @override
  State<YomimonoContent> createState() => _YomimonoContentState();
}

class _YomimonoContentState extends State<YomimonoContent> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('yomimono')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('エラーが発生しました: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'まだ記事がありません',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'レシピを生成すると記事が作成されます',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YomimonoDetailScreen(
                        postData: data,
                        docId: doc.id,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイトル
                      Text(
                        data['title'] ?? 'タイトルなし',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // 抜粋
                      if (data['excerpt'] != null && data['excerpt'].toString().isNotEmpty)
                        Text(
                          data['excerpt'],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // メタ情報
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(data['date']),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['author'] ?? '作者不明',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return '日付不明';
    
    try {
      DateTime date;
      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        return '日付不明';
      }
      
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return '日付不明';
    }
  }
}

// よみもの詳細画面
class YomimonoDetailScreen extends StatelessWidget {
  final Map<String, dynamic> postData;
  final String docId;

  const YomimonoDetailScreen({
    super.key,
    required this.postData,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(postData['title'] ?? 'よみもの'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 共有ボタン（オプション）
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 共有機能の実装（オプション）
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('共有機能は準備中です')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            Text(
              postData['title'] ?? 'タイトルなし',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            
            // メタ情報
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(postData['date']),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.person,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  postData['author'] ?? '作者不明',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // HTMLコンテンツ
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: HtmlWidget(
                postData['content'] ?? '',
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                // カスタムスタイル
                customStylesBuilder: (element) {
                  if (element.localName == 'h2') {
                    return {
                      'color': '#${Theme.of(context).colorScheme.primary.value.toRadixString(16).padLeft(8, '0')}',
                      'margin-bottom': '16px',
                      'margin-top': '24px',
                    };
                  }
                  if (element.localName == 'h3') {
                    return {
                      'color': '#${Theme.of(context).colorScheme.secondary.value.toRadixString(16).padLeft(8, '0')}',
                      'margin-bottom': '12px',
                      'margin-top': '20px',
                    };
                  }
                  if (element.localName == 'blockquote') {
                    return {
                      'border-left': '4px solid #${Theme.of(context).colorScheme.primary.value.toRadixString(16).padLeft(8, '0')}',
                      'padding-left': '16px',
                      'margin': '16px 0',
                      'font-style': 'italic',
                      'background-color': '#${Theme.of(context).colorScheme.primaryContainer.value.toRadixString(16).padLeft(8, '0')}',
                      'padding': '16px',
                      'border-radius': '8px',
                    };
                  }
                  return null;
                },
                // リンククリック時の処理
                onTapUrl: (url) async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    return true;
                  }
                  return false;
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // フッター
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'この記事が参考になりましたか？他の記事もぜひご覧ください。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return '日付不明';
    
    try {
      DateTime date;
      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        return '日付不明';
      }
      
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return '日付不明';
    }
  }
}
