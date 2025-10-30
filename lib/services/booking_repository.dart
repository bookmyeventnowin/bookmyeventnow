import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';

class BookingRepository {
  BookingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _collectionPath = 'bookings';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionPath);

  Stream<List<Booking>> streamUserBookings(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Booking.fromFirestore).toList());
  }

  Stream<List<Booking>> streamVendorBookings(String ownerUid) {
    return _collection
        .where('vendorOwnerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Booking.fromFirestore).toList());
  }

  Future<bool> hasVendorBookingConflict({
    required String vendorId,
    required DateTime eventDate,
    required String userId,
  }) async {
    final targetDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final snapshot = await _collection
        .where('vendorId', isEqualTo: vendorId)
        .where('eventDate', isEqualTo: Timestamp.fromDate(targetDate))
        .get();

    for (final doc in snapshot.docs) {
      final booking = Booking.fromFirestore(doc);
      if (booking.status == BookingStatus.paid && booking.userId != userId) {
        return true;
      }
    }
    return false;
  }

  Future<String> createBooking({
    required String userId,
    required String userName,
    required String userEmail,
    required String vendorId,
    required String vendorOwnerUid,
    required String vendorName,
    required String vendorCategory,
    required double pricePerHour,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime eventDate,
  }) async {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours.clamp(1, 24);
    final totalAmount = pricePerHour * hours;
    final docRef = await _collection.add({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'vendorId': vendorId,
      'vendorOwnerUid': vendorOwnerUid,
      'vendorName': vendorName,
      'vendorCategory': vendorCategory,
      'pricePerHour': pricePerHour,
      'hoursBooked': hours,
      'totalAmount': totalAmount,
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': BookingStatus.pending.storageValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
    String? paymentReference,
  }) async {
    final docRef = _collection.doc(bookingId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Booking not found');
    }
    final booking = Booking.fromFirestore(snapshot);

    await docRef.update({
      'status': status.storageValue,
      'paymentReference': paymentReference,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (status == BookingStatus.paid) {
      await _declineConflictingBookings(
        vendorId: booking.vendorId,
        eventDate: booking.eventDate,
        excludeBookingId: bookingId,
      );
    }
  }

  Future<void> _declineConflictingBookings({
    required String vendorId,
    required DateTime eventDate,
    required String excludeBookingId,
  }) async {
    final targetDate = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final snapshot = await _collection
        .where('vendorId', isEqualTo: vendorId)
        .where('eventDate', isEqualTo: Timestamp.fromDate(targetDate))
        .get();

    for (final doc in snapshot.docs) {
      if (doc.id == excludeBookingId) continue;
      final booking = Booking.fromFirestore(doc);
      if (booking.status == BookingStatus.paid) continue;

      await doc.reference.update({
        'status': BookingStatus.declined.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
