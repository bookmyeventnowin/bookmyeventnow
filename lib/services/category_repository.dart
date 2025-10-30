import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

class CategoryRepository {
  CategoryRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Category>> streamCategories({String? vendorId}) {
    final collection = _resolveCollection(vendorId);
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromFirestore(doc.data(), doc.id)).toList();
    });
  }

  CollectionReference<Map<String, dynamic>> _resolveCollection(String? vendorId) {
    if (vendorId != null && vendorId.isNotEmpty) {
      return _firestore.collection('vendors').doc(vendorId).collection('categories');
    }
    return _firestore.collection('categories');
  }
}
