import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreLoader {
  static Future<List<Map<String, dynamic>>> loadCollection(String collectionPath) async {
    final querySnapshot = await FirebaseFirestore.instance.collection(collectionPath).get();
    if (querySnapshot.docs.isEmpty) return [];

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }
}
