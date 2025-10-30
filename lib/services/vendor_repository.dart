import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';
import '../models/vendor.dart';

class VendorRepository {
  VendorRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _collectionPath = 'vendors';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionPath);

  Stream<List<Vendor>> streamVendorsForCategory({required Category category}) {
    return _collection.snapshots().map((snapshot) {
      final vendors = snapshot.docs
          .map((doc) => Vendor.fromFirestore(doc.data(), doc.id))
          .toList();
      return vendors
          .where(
            (vendor) =>
                vendor.matchesCategory(category) && vendor.isSubscriptionActive,
          )
          .toList();
    });
  }

  Stream<Vendor?> streamVendorForOwner(String ownerUid) {
    return _collection
        .where('ownerUid', isEqualTo: ownerUid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return Vendor.fromFirestore(doc.data(), doc.id);
        });
  }

  Future<void> upsertVendor({
    required String? id,
    required String ownerUid,
    required Map<String, dynamic> data,
  }) async {
    final payload = Map<String, dynamic>.from(data)
      ..['ownerUid'] = ownerUid
      ..['updatedAt'] = FieldValue.serverTimestamp();

    payload.putIfAbsent('subscriptionStatus', () => 'inactive');
    payload.putIfAbsent('subscriptionExpiresAt', () => null);
    payload.putIfAbsent('subscriptionPaidAt', () => null);
    payload.putIfAbsent('subscriptionAmountLastPaid', () => 0);

    if (id == null) {
      await _collection.add(
        payload..['createdAt'] = FieldValue.serverTimestamp(),
      );
    } else {
      await _collection.doc(id).set(payload, SetOptions(merge: true));
    }
  }

  Future<void> deleteVendor(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> activateSubscription({
    required String vendorId,
    required double amount,
    Duration duration = const Duration(days: 365),
  }) async {
    final docRef = _collection.doc(vendorId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Vendor not found');
      }
      final data = snapshot.data() ?? {};
      DateTime now = DateTime.now();
      DateTime? currentExpiry;
      final rawExpiry = data['subscriptionExpiresAt'];
      if (rawExpiry is Timestamp) {
        currentExpiry = rawExpiry.toDate();
      } else if (rawExpiry is DateTime) {
        currentExpiry = rawExpiry;
      }
      final base = (currentExpiry != null && currentExpiry.isAfter(now))
          ? currentExpiry
          : now;
      final newExpiry = base.add(duration);

      transaction.update(docRef, {
        'subscriptionStatus': 'active',
        'subscriptionPaidAt': Timestamp.fromDate(now),
        'subscriptionExpiresAt': Timestamp.fromDate(newExpiry),
        'subscriptionAmountLastPaid': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
