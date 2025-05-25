import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestoreの操作をラップするクラス
class FirestoreWrapper {
  final FirebaseFirestore firestore;

  FirestoreWrapper(this.firestore);

  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(String path) {
    return firestore.collection(path).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String path, String id) {
    return firestore.collection(path).doc(id).get();
  }

  Future<void> setDocument(String path, String id, Map<String, dynamic> data) {
    return firestore.collection(path).doc(id).set(data);
  }

  Future<void> deleteDocument(String path, String id) {
    return firestore.collection(path).doc(id).delete();
  }

  Future<void> updateDocument(String path, String id, Map<String, dynamic> data) {
    return firestore.collection(path).doc(id).update(data);
  }

  /// 新規ドキュメントをコレクションに追加し、生成されたIDを返す
  Future<String> addDocument(String path, Map<String, dynamic> data) async {
    final docRef = await firestore.collection(path).add(data);
    return docRef.id;
  }

  /// Firestoreのトランザクションをラップ
  Future<T> runTransaction<T>(Future<T> Function(Transaction) transactionHandler) {
    return firestore.runTransaction(transactionHandler);
  }
}
