import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';

class RatingSummary {
  final double? average;
  final int count;
  const RatingSummary({required this.average, required this.count});

  static const RatingSummary empty =
      RatingSummary(average: null, count: 0);

  bool get hasRatings => count > 0 && average != null;
}

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
    try {
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
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
      // When the caller lacks read permission, assume no conflict so the
      // proposal can proceed. Vendors still have visibility via their own view.
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
    String? orderId,
  }) async {
    final duration = endTime.difference(startTime);
    final hours = (duration.inMinutes / 60).ceil().clamp(1, 24);
    final totalAmount = pricePerHour * hours;
    final docRef = await _collection.add({
      'orderId': orderId,
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
      'bookingType': 'standard',
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': BookingStatus.pending.storageValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<String> createCateringProposal({
    required String userId,
    required String userName,
    required String userEmail,
    required String vendorId,
    required String vendorOwnerUid,
    required String vendorName,
    required String vendorCategory,
    required List<ProposalMenuItem> menu,
    required int guestCount,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime eventDate,
    required DateTime deliveryTime,
    required String deliveryAddress,
    required bool deliveryRequired,
    String? orderId,
  }) async {
    final duration = endTime.difference(startTime);
    final hours = (duration.inMinutes / 60).ceil().clamp(1, 24);
    final docRef = await _collection.add({
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'vendorId': vendorId,
      'vendorOwnerUid': vendorOwnerUid,
      'vendorName': vendorName,
      'vendorCategory': vendorCategory,
      'pricePerHour': 0,
      'hoursBooked': hours,
      'totalAmount': 0,
      'bookingType': 'catering',
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': BookingStatus.pending.storageValue,
      'proposalStatus': ProposalStatus.sent.storageValue,
      'proposalMenu': menu.map((item) => item.toMap()).toList(),
      'proposalGuestCount': guestCount,
      'proposalDeliveryRequired': deliveryRequired,
      'proposalDeliveryAddress': deliveryAddress,
      'proposalDeliveryTime': Timestamp.fromDate(deliveryTime),
      'vendorQuoteAmount': null,
      'userCounterAmount': null,
      'agreedAmount': null,
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

  Future<void> vendorSendQuote({
    required String bookingId,
    required double amount,
  }) async {
    await _collection.doc(bookingId).update({
      'proposalStatus': ProposalStatus.vendorQuoted.storageValue,
      'vendorQuoteAmount': amount,
      'totalAmount': amount,
      'agreedAmount': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> userAcceptQuote({
    required String bookingId,
  }) async {
    final docRef = _collection.doc(bookingId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) throw StateError('Booking not found');
    final booking = Booking.fromFirestore(snapshot);
    final amount = booking.vendorQuoteAmount ?? booking.userCounterAmount ?? 0;
    await docRef.update({
      'status': BookingStatus.accepted.storageValue,
      'proposalStatus': ProposalStatus.vendorAccepted.storageValue,
      'agreedAmount': amount,
      'totalAmount': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> userCounterQuote({
    required String bookingId,
    required double amount,
  }) async {
    await _collection.doc(bookingId).update({
      'proposalStatus': ProposalStatus.userCounter.storageValue,
      'userCounterAmount': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> vendorRespondToCounter({
    required String bookingId,
    required bool accept,
  }) async {
    final docRef = _collection.doc(bookingId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) throw StateError('Booking not found');
    final booking = Booking.fromFirestore(snapshot);
    if (accept) {
      final amount = booking.userCounterAmount ?? booking.vendorQuoteAmount ?? 0;
      await docRef.update({
        'status': BookingStatus.accepted.storageValue,
        'proposalStatus': ProposalStatus.vendorAccepted.storageValue,
        'agreedAmount': amount,
        'vendorQuoteAmount': amount,
        'totalAmount': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'status': BookingStatus.declined.storageValue,
        'proposalStatus': ProposalStatus.vendorDeclined.storageValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> submitRating({
    required String bookingId,
    required int rating,
    String? review,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final bookingRef = _collection.doc(bookingId);
      final bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        throw Exception('Booking not found');
      }
      final data = bookingSnap.data()!;
      final vendorId = data['vendorId'] as String? ?? '';
      final previousRatingRaw = data['rating'];
      final previousRating =
          previousRatingRaw is num ? previousRatingRaw.toDouble() : null;

      DocumentReference<Map<String, dynamic>>? vendorRef;
      DocumentSnapshot<Map<String, dynamic>>? vendorSnap;
      if (vendorId.isNotEmpty) {
        vendorRef = _firestore.collection('vendors').doc(vendorId);
        vendorSnap = await transaction.get(vendorRef);
      }

      double currentTotal = 0;
      int currentCount = 0;
      if (vendorSnap != null && vendorSnap.exists) {
        final vendorData = vendorSnap.data();
        if (vendorData != null) {
          final totalRaw = vendorData['ratingTotal'];
          final countRaw = vendorData['ratingCount'];
          if (totalRaw is num) currentTotal = totalRaw.toDouble();
          if (countRaw is num) currentCount = countRaw.toInt();
        }
      }

      double newTotal = currentTotal;
      int newCount = currentCount;
      if (previousRating != null && previousRating > 0) {
        newTotal -= previousRating;
      } else {
        newCount += 1;
      }
      newTotal += rating.toDouble();
      final newAverage = newCount > 0 ? newTotal / newCount : 0;

      transaction.update(bookingRef, {
        'rating': rating,
        'review': review,
        'ratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (vendorRef != null) {
        transaction.set(
          vendorRef,
          {
            'ratingTotal': newTotal,
            'ratingCount': newCount,
            'ratingAverage': newAverage,
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  Stream<RatingSummary> streamVendorRatingSummary(String vendorId) {
    return _collection
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return RatingSummary.empty;
          }
          double total = 0;
          int count = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final ratingRaw = data['rating'];
            if (ratingRaw is num && ratingRaw > 0) {
              total += ratingRaw.toDouble();
              count++;
            }
          }
          if (count == 0) return RatingSummary.empty;
          final average = total / count;
          return RatingSummary(average: average, count: count);
        });
  }
}
