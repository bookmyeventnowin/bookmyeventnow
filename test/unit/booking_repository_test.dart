// test/unit/booking_repository_test.dart
//
// Unit tests for BookingRepository using FakeFirebaseFirestore.
// Tests Firestore reads, writes, status transitions, conflict detection,
// catering proposals, rating, and subscription logic.
//
// Run: flutter test test/unit/booking_repository_test.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyeventnow/services/booking_repository.dart';
import 'package:bookmyeventnow/models/booking.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Future<String> _createStandardBooking(
  BookingRepository repo, {
  String userId = 'user-001',
  String vendorId = 'vendor-001',
  DateTime? eventDate,
  String? orderId,
}) {
  final date = eventDate ?? DateTime(2026, 9, 20);
  return repo.createBooking(
    userId: userId,
    userName: 'Naga Raj',
    userEmail: 'naga@example.com',
    vendorId: vendorId,
    vendorOwnerUid: 'owner-001',
    vendorName: 'Royal Decorators',
    vendorCategory: 'Decoration',
    pricePerHour: 2000.0,
    startTime: DateTime(date.year, date.month, date.day, 10, 0),
    endTime: DateTime(date.year, date.month, date.day, 13, 0),
    eventDate: date,
    orderId: orderId,
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore firestore;
  late BookingRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = BookingRepository(firestore: firestore);
  });

  // ── createBooking ─────────────────────────────────────────────────────────

  group('BookingRepository.createBooking()', () {
    test('creates a booking document in Firestore', () async {
      final id = await _createStandardBooking(repo);
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.exists, isTrue);
    });

    test('created booking has pending status', () async {
      final id = await _createStandardBooking(repo);
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['status'], 'pending');
    });

    test('calculates totalAmount correctly (3 hours × ₹2000 = ₹6000)', () async {
      final id = await _createStandardBooking(repo);
      final snap = await firestore.collection('bookings').doc(id).get();
      // startTime 10:00, endTime 13:00 → 3 hours
      expect(snap.data()!['totalAmount'], 6000.0);
    });

    test('stores userId and vendorId correctly', () async {
      final id = await _createStandardBooking(repo);
      final snap = await firestore.collection('bookings').doc(id).get();
      final data = snap.data()!;
      expect(data['userId'], 'user-001');
      expect(data['vendorId'], 'vendor-001');
    });

    test('hoursBooked is ceiling of duration in minutes/60', () async {
      // 10:00 → 13:30 = 3.5h → ceil = 4
      final date = DateTime(2026, 9, 25);
      final id = await repo.createBooking(
        userId: 'user-001',
        userName: 'Test',
        userEmail: 'test@example.com',
        vendorId: 'vendor-001',
        vendorOwnerUid: 'owner-001',
        vendorName: 'Test Vendor',
        vendorCategory: 'Catering',
        pricePerHour: 1000.0,
        startTime: DateTime(date.year, date.month, date.day, 10, 0),
        endTime: DateTime(date.year, date.month, date.day, 13, 30),
        eventDate: date,
      );
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['hoursBooked'], 4);
    });
  });

  // ── streamUserBookings ────────────────────────────────────────────────────

  group('BookingRepository.streamUserBookings()', () {
    test('streams bookings for the correct user only', () async {
      await _createStandardBooking(repo, userId: 'user-001');
      await _createStandardBooking(repo, userId: 'user-999');

      final stream = repo.streamUserBookings('user-001');
      final bookings = await stream.first;
      expect(bookings.length, 1);
      expect(bookings.first.userId, 'user-001');
    });

    test('returns empty list when user has no bookings', () async {
      final stream = repo.streamUserBookings('no-bookings-user');
      final bookings = await stream.first;
      expect(bookings, isEmpty);
    });
  });

  // ── streamVendorBookings ──────────────────────────────────────────────────

  group('BookingRepository.streamVendorBookings()', () {
    test('streams bookings for the correct vendor owner', () async {
      await _createStandardBooking(repo, vendorId: 'vendor-001');
      final stream = repo.streamVendorBookings('owner-001');
      final bookings = await stream.first;
      expect(bookings.every((b) => b.vendorOwnerUid == 'owner-001'), isTrue);
    });
  });

  // ── updateStatus ──────────────────────────────────────────────────────────

  group('BookingRepository.updateStatus()', () {
    test('updates booking status to accepted', () async {
      final id = await _createStandardBooking(repo);
      await repo.updateStatus(bookingId: id, status: BookingStatus.accepted);
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['status'], 'accepted');
    });

    test('updates booking status to paid with payment reference', () async {
      final id = await _createStandardBooking(repo);
      await repo.updateStatus(
        bookingId: id,
        status: BookingStatus.paid,
        paymentReference: 'pay_ABC123',
      );
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['status'], 'paid');
      expect(snap.data()!['paymentReference'], 'pay_ABC123');
    });

    test('throws StateError when booking does not exist', () async {
      expect(
        () => repo.updateStatus(
          bookingId: 'non-existent-id',
          status: BookingStatus.paid,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── conflict detection ────────────────────────────────────────────────────

  group('BookingRepository.hasVendorBookingConflict()', () {
    test('returns false when no paid booking exists on same date', () async {
      await _createStandardBooking(repo, vendorId: 'vendor-conflict');
      // booking is pending, not paid
      final hasConflict = await repo.hasVendorBookingConflict(
        vendorId: 'vendor-conflict',
        eventDate: DateTime(2026, 9, 20),
        userId: 'user-002',
      );
      expect(hasConflict, isFalse);
    });

    test('returns false when paid booking is by the same user', () async {
      final id = await _createStandardBooking(
        repo,
        userId: 'user-001',
        vendorId: 'vendor-x',
        eventDate: DateTime(2026, 9, 21),
      );
      await repo.updateStatus(bookingId: id, status: BookingStatus.paid);
      // Same user checking conflict → should be false
      final hasConflict = await repo.hasVendorBookingConflict(
        vendorId: 'vendor-x',
        eventDate: DateTime(2026, 9, 21),
        userId: 'user-001',
      );
      expect(hasConflict, isFalse);
    });

    test('returns true when paid booking exists for different user', () async {
      final id = await _createStandardBooking(
        repo,
        userId: 'user-001',
        vendorId: 'vendor-y',
        eventDate: DateTime(2026, 9, 22),
      );
      await repo.updateStatus(bookingId: id, status: BookingStatus.paid);

      final hasConflict = await repo.hasVendorBookingConflict(
        vendorId: 'vendor-y',
        eventDate: DateTime(2026, 9, 22),
        userId: 'user-002',
      );
      expect(hasConflict, isTrue);
    });
  });

  // ── auto-decline conflicting bookings on payment ───────────────────────────

  group('Auto-decline on payment', () {
    test('declines other pending bookings on same vendor+date after payment', () async {
      final eventDate = DateTime(2026, 10, 5);
      final paidId = await _createStandardBooking(
        repo,
        userId: 'user-001',
        vendorId: 'vendor-z',
        eventDate: eventDate,
      );
      final otherId = await _createStandardBooking(
        repo,
        userId: 'user-002',
        vendorId: 'vendor-z',
        eventDate: eventDate,
      );

      await repo.updateStatus(bookingId: paidId, status: BookingStatus.paid);

      final otherSnap = await firestore.collection('bookings').doc(otherId).get();
      expect(otherSnap.data()!['status'], 'declined');
    });

    test('does not decline the booking that was paid', () async {
      final id = await _createStandardBooking(
        repo,
        vendorId: 'vendor-noself',
        eventDate: DateTime(2026, 10, 6),
      );
      await repo.updateStatus(bookingId: id, status: BookingStatus.paid);
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['status'], 'paid');
    });
  });

  // ── catering proposal ─────────────────────────────────────────────────────

  group('BookingRepository.createCateringProposal()', () {
    test('creates a catering booking with proposalStatus=sent', () async {
      final date = DateTime(2026, 11, 10);
      final id = await repo.createCateringProposal(
        userId: 'user-001',
        userName: 'Naga',
        userEmail: 'naga@example.com',
        vendorId: 'vendor-catering',
        vendorOwnerUid: 'owner-catering',
        vendorName: 'Royal Caterers',
        vendorCategory: 'Catering',
        menu: [
          const ProposalMenuItem(name: 'Biryani', isVeg: false),
          const ProposalMenuItem(name: 'Paneer Butter Masala', isVeg: true),
        ],
        guestCount: 50,
        startTime: DateTime(date.year, date.month, date.day, 12, 0),
        endTime: DateTime(date.year, date.month, date.day, 15, 0),
        eventDate: date,
        deliveryTime: DateTime(date.year, date.month, date.day, 11, 30),
        deliveryAddress: '123 Main Street, Chennai',
        deliveryRequired: true,
      );

      final snap = await firestore.collection('bookings').doc(id).get();
      final data = snap.data()!;
      expect(data['bookingType'], 'catering');
      expect(data['proposalStatus'], 'sent');
      expect(data['proposalGuestCount'], 50);
      expect(data['proposalDeliveryRequired'], isTrue);
      expect((data['proposalMenu'] as List).length, 2);
    });
  });

  // ── catering quote negotiation ────────────────────────────────────────────

  group('Catering quote negotiation flow', () {
    late String proposalId;

    setUp(() async {
      final date = DateTime(2026, 12, 1);
      proposalId = await repo.createCateringProposal(
        userId: 'user-001',
        userName: 'User',
        userEmail: 'u@e.com',
        vendorId: 'v-001',
        vendorOwnerUid: 'o-001',
        vendorName: 'Caterers',
        vendorCategory: 'Catering',
        menu: [const ProposalMenuItem(name: 'Rice', isVeg: true)],
        guestCount: 100,
        startTime: DateTime(date.year, date.month, date.day, 12, 0),
        endTime: DateTime(date.year, date.month, date.day, 15, 0),
        eventDate: date,
        deliveryTime: DateTime(date.year, date.month, date.day, 11, 0),
        deliveryAddress: 'Venue A',
        deliveryRequired: false,
      );
    });

    test('vendorSendQuote sets proposalStatus to vendorQuoted', () async {
      await repo.vendorSendQuote(bookingId: proposalId, amount: 25000.0);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['proposalStatus'], 'vendorQuoted');
      expect(snap.data()!['vendorQuoteAmount'], 25000.0);
    });

    test('userCounterQuote sets proposalStatus to userCounter', () async {
      await repo.vendorSendQuote(bookingId: proposalId, amount: 25000.0);
      await repo.userCounterQuote(bookingId: proposalId, amount: 22000.0);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['proposalStatus'], 'userCounter');
      expect(snap.data()!['userCounterAmount'], 22000.0);
    });

    test('userAcceptQuote sets status to accepted and agreed amount', () async {
      await repo.vendorSendQuote(bookingId: proposalId, amount: 25000.0);
      await repo.userAcceptQuote(bookingId: proposalId);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['status'], 'accepted');
      expect(snap.data()!['agreedAmount'], 25000.0);
    });

    test('vendorRespondToCounter accept → sets status to accepted', () async {
      await repo.vendorSendQuote(bookingId: proposalId, amount: 25000.0);
      await repo.userCounterQuote(bookingId: proposalId, amount: 22000.0);
      await repo.vendorRespondToCounter(bookingId: proposalId, accept: true);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['status'], 'accepted');
      expect(snap.data()!['agreedAmount'], 22000.0);
    });

    test('vendorRespondToCounter reject → sets status to declined', () async {
      await repo.vendorSendQuote(bookingId: proposalId, amount: 25000.0);
      await repo.userCounterQuote(bookingId: proposalId, amount: 22000.0);
      await repo.vendorRespondToCounter(bookingId: proposalId, accept: false);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['status'], 'declined');
      expect(snap.data()!['proposalStatus'], 'vendorDeclined');
    });
  });

  // ── rating ────────────────────────────────────────────────────────────────

  group('BookingRepository.submitRating()', () {
    test('saves rating and review on the booking document', () async {
      // Seed a vendor doc for the transaction
      await firestore.collection('vendors').doc('vendor-001').set({
        'ratingTotal': 0.0,
        'ratingCount': 0,
        'ratingAverage': 0.0,
      });

      final id = await _createStandardBooking(repo, vendorId: 'vendor-001');
      await repo.submitRating(bookingId: id, rating: 5, review: 'Excellent!');

      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['rating'], 5);
      expect(snap.data()!['review'], 'Excellent!');
    });

    test('updates vendor ratingAverage correctly', () async {
      await firestore.collection('vendors').doc('v-rate').set({
        'ratingTotal': 0.0,
        'ratingCount': 0,
        'ratingAverage': 0.0,
      });

      final id = await _createStandardBooking(repo, vendorId: 'v-rate');
      await repo.submitRating(bookingId: id, rating: 4);

      final vendorSnap = await firestore.collection('vendors').doc('v-rate').get();
      expect(vendorSnap.data()!['ratingAverage'], closeTo(4.0, 0.01));
      expect(vendorSnap.data()!['ratingCount'], 1);
    });

    test('throws when booking does not exist', () async {
      expect(
        () => repo.submitRating(bookingId: 'bad-id', rating: 5),
        throwsA(isA<Exception>()),
      );
    });
  });
}
