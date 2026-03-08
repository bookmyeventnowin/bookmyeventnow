// integration_test/booking_flow_test.dart
//
// Integration tests for the Booking & Payment flow.
// Tests vendor browsing, booking creation, catering proposals,
// quote negotiation, payment trigger, and post-payment rating.
//
// Prerequisites:
//   - Device/emulator connected with Firebase emulator running
//   - A test user signed in with User role
//
// Run:
//   flutter test integration_test/booking_flow_test.dart \
//     --device-id emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookmyeventnow/services/booking_repository.dart';
import 'package:bookmyeventnow/models/booking.dart';
import 'package:bookmyeventnow/utils/fee_utils.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

FakeFirebaseFirestore _seedFirestore() {
  final firestore = FakeFirebaseFirestore();

  firestore.collection('vendors').doc('vendor-dec-001').set({
    'ownerUid': 'owner-dec-001',
    'name': 'Royal Decorators',
    'category': 'Decoration',
    'pricePerHour': 2500.0,
    'description': 'Premium decoration services for all events',
    'subscriptionStatus': 'active',
    'subscriptionExpiresAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 300)),
    ),
    'ratingAverage': 4.8,
    'ratingCount': 25,
    'ratingTotal': 120.0,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  firestore.collection('vendors').doc('vendor-cat-001').set({
    'ownerUid': 'owner-cat-001',
    'name': 'Grand Caterers',
    'category': 'Catering',
    'pricePerHour': 0.0,
    'description': 'Full catering services for 50-500 guests',
    'subscriptionStatus': 'active',
    'subscriptionExpiresAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 200)),
    ),
    'ratingAverage': 4.5,
    'ratingCount': 40,
    'ratingTotal': 180.0,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  return firestore;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late BookingRepository bookingRepo;

  setUp(() {
    firestore = _seedFirestore();
    bookingRepo = BookingRepository(firestore: firestore);
  });

  // ── Standard Booking Flow ─────────────────────────────────────────────────

  group('[BOOKING] Standard Booking Creation', () {
    test('BMEN-BK-001 | Creates a standard booking with correct fields', () async {
      final eventDate = DateTime(2026, 9, 15);
      final id = await bookingRepo.createBooking(
        userId: 'user-001',
        userName: 'Naga Raj',
        userEmail: 'naga@example.com',
        vendorId: 'vendor-dec-001',
        vendorOwnerUid: 'owner-dec-001',
        vendorName: 'Royal Decorators',
        vendorCategory: 'Decoration',
        pricePerHour: 2500.0,
        startTime: DateTime(eventDate.year, eventDate.month, eventDate.day, 10, 0),
        endTime: DateTime(eventDate.year, eventDate.month, eventDate.day, 14, 0),
        eventDate: eventDate,
      );

      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.exists, isTrue);

      final data = snap.data()!;
      expect(data['userId'], 'user-001');
      expect(data['vendorId'], 'vendor-dec-001');
      expect(data['status'], 'pending');
      expect(data['bookingType'], 'standard');
      expect(data['hoursBooked'], 4);
      expect(data['totalAmount'], 10000.0); // 4h × 2500
    });

    test('BMEN-BK-002 | Hours booked uses ceiling for partial hours', () async {
      final date = DateTime(2026, 9, 16);
      final id = await bookingRepo.createBooking(
        userId: 'user-001',
        userName: 'Naga',
        userEmail: 'naga@example.com',
        vendorId: 'vendor-dec-001',
        vendorOwnerUid: 'owner-dec-001',
        vendorName: 'Royal Decorators',
        vendorCategory: 'Decoration',
        pricePerHour: 2500.0,
        startTime: DateTime(date.year, date.month, date.day, 10, 0),
        endTime: DateTime(date.year, date.month, date.day, 12, 30), // 2.5h → 3
        eventDate: date,
      );
      final snap = await firestore.collection('bookings').doc(id).get();
      expect(snap.data()!['hoursBooked'], 3);
    });

    test('BMEN-BK-003 | Booking streams correctly for user', () async {
      final date = DateTime(2026, 10, 1);
      await bookingRepo.createBooking(
        userId: 'stream-user',
        userName: 'Stream User',
        userEmail: 'stream@example.com',
        vendorId: 'vendor-dec-001',
        vendorOwnerUid: 'owner-dec-001',
        vendorName: 'Royal Decorators',
        vendorCategory: 'Decoration',
        pricePerHour: 2500.0,
        startTime: DateTime(date.year, date.month, date.day, 9, 0),
        endTime: DateTime(date.year, date.month, date.day, 11, 0),
        eventDate: date,
      );

      final bookings = await bookingRepo.streamUserBookings('stream-user').first;
      expect(bookings.length, 1);
      expect(bookings.first.userId, 'stream-user');
    });
  });

  // ── Booking Status Transitions ────────────────────────────────────────────

  group('[BOOKING] Status Transitions', () {
    late String bookingId;
    final eventDate = DateTime(2026, 10, 10);

    setUp(() async {
      bookingId = await bookingRepo.createBooking(
        userId: 'user-001',
        userName: 'Naga',
        userEmail: 'naga@example.com',
        vendorId: 'vendor-dec-001',
        vendorOwnerUid: 'owner-dec-001',
        vendorName: 'Royal Decorators',
        vendorCategory: 'Decoration',
        pricePerHour: 2500.0,
        startTime: DateTime(eventDate.year, eventDate.month, eventDate.day, 10, 0),
        endTime: DateTime(eventDate.year, eventDate.month, eventDate.day, 12, 0),
        eventDate: eventDate,
      );
    });

    test('BMEN-BK-004 | Booking status transitions: pending → accepted', () async {
      await bookingRepo.updateStatus(
        bookingId: bookingId,
        status: BookingStatus.accepted,
      );
      final snap = await firestore.collection('bookings').doc(bookingId).get();
      expect(snap.data()!['status'], 'accepted');
    });

    test('BMEN-BK-005 | Booking status transitions: accepted → paid with reference',
        () async {
      await bookingRepo.updateStatus(
        bookingId: bookingId,
        status: BookingStatus.accepted,
      );
      await bookingRepo.updateStatus(
        bookingId: bookingId,
        status: BookingStatus.paid,
        paymentReference: 'rzp_pay_TEST123',
      );
      final snap = await firestore.collection('bookings').doc(bookingId).get();
      final data = snap.data()!;
      expect(data['status'], 'paid');
      expect(data['paymentReference'], 'rzp_pay_TEST123');
    });

    test('BMEN-BK-006 | Booking can be declined (pending → declined)', () async {
      await bookingRepo.updateStatus(
        bookingId: bookingId,
        status: BookingStatus.declined,
      );
      final snap = await firestore.collection('bookings').doc(bookingId).get();
      expect(snap.data()!['status'], 'declined');
    });
  });

  // ── Conflict Detection ────────────────────────────────────────────────────

  group('[BOOKING] Date Conflict Detection', () {
    final conflictDate = DateTime(2026, 11, 5);

    test('BMEN-BK-007 | No conflict when no paid booking exists on same date',
        () async {
      await bookingRepo.createBooking(
        userId: 'u1',
        userName: 'User1',
        userEmail: 'u1@test.com',
        vendorId: 'v-conflict',
        vendorOwnerUid: 'o-conflict',
        vendorName: 'Vendor',
        vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(conflictDate.year, conflictDate.month, conflictDate.day, 10, 0),
        endTime: DateTime(conflictDate.year, conflictDate.month, conflictDate.day, 12, 0),
        eventDate: conflictDate,
      );

      final conflict = await bookingRepo.hasVendorBookingConflict(
        vendorId: 'v-conflict',
        eventDate: conflictDate,
        userId: 'u2',
      );
      expect(conflict, isFalse);
    });

    test('BMEN-BK-008 | Conflict detected when paid booking exists for different user',
        () async {
      final id = await bookingRepo.createBooking(
        userId: 'u1',
        userName: 'User1',
        userEmail: 'u1@test.com',
        vendorId: 'v-paid',
        vendorOwnerUid: 'o-paid',
        vendorName: 'Vendor',
        vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(conflictDate.year, conflictDate.month, conflictDate.day, 10, 0),
        endTime: DateTime(conflictDate.year, conflictDate.month, conflictDate.day, 12, 0),
        eventDate: conflictDate,
      );
      await bookingRepo.updateStatus(bookingId: id, status: BookingStatus.paid);

      final conflict = await bookingRepo.hasVendorBookingConflict(
        vendorId: 'v-paid',
        eventDate: conflictDate,
        userId: 'u2',
      );
      expect(conflict, isTrue);
    });

    test('BMEN-BK-009 | Payment auto-declines competing bookings on same date',
        () async {
      final date = DateTime(2026, 12, 12);
      final paidId = await bookingRepo.createBooking(
        userId: 'u1',
        userName: 'U1',
        userEmail: 'u1@t.com',
        vendorId: 'v-auto-decline',
        vendorOwnerUid: 'o-a',
        vendorName: 'V',
        vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(date.year, date.month, date.day, 10, 0),
        endTime: DateTime(date.year, date.month, date.day, 12, 0),
        eventDate: date,
      );
      final otherId = await bookingRepo.createBooking(
        userId: 'u2',
        userName: 'U2',
        userEmail: 'u2@t.com',
        vendorId: 'v-auto-decline',
        vendorOwnerUid: 'o-a',
        vendorName: 'V',
        vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(date.year, date.month, date.day, 13, 0),
        endTime: DateTime(date.year, date.month, date.day, 15, 0),
        eventDate: date,
      );

      await bookingRepo.updateStatus(bookingId: paidId, status: BookingStatus.paid);

      final otherSnap = await firestore.collection('bookings').doc(otherId).get();
      expect(otherSnap.data()!['status'], 'declined');
    });
  });

  // ── Catering Proposal Flow ────────────────────────────────────────────────

  group('[BOOKING] Catering Proposal & Quote Negotiation', () {
    late String proposalId;
    final proposalDate = DateTime(2026, 12, 20);

    setUp(() async {
      proposalId = await bookingRepo.createCateringProposal(
        userId: 'user-001',
        userName: 'Naga Raj',
        userEmail: 'naga@example.com',
        vendorId: 'vendor-cat-001',
        vendorOwnerUid: 'owner-cat-001',
        vendorName: 'Grand Caterers',
        vendorCategory: 'Catering',
        menu: [
          const ProposalMenuItem(name: 'Chicken Biryani', isVeg: false),
          const ProposalMenuItem(name: 'Veg Biryani', isVeg: true),
          const ProposalMenuItem(name: 'Dal Makhani', isVeg: true),
        ],
        guestCount: 150,
        startTime: DateTime(proposalDate.year, proposalDate.month, proposalDate.day, 12, 0),
        endTime: DateTime(proposalDate.year, proposalDate.month, proposalDate.day, 16, 0),
        eventDate: proposalDate,
        deliveryTime: DateTime(proposalDate.year, proposalDate.month, proposalDate.day, 11, 0),
        deliveryAddress: '45 Gandhi Nagar, Chennai',
        deliveryRequired: true,
      );
    });

    test('BMEN-BK-010 | Catering proposal is created with correct fields', () async {
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      final data = snap.data()!;
      expect(data['bookingType'], 'catering');
      expect(data['proposalStatus'], 'sent');
      expect(data['proposalGuestCount'], 150);
      expect(data['proposalDeliveryRequired'], isTrue);
      expect((data['proposalMenu'] as List).length, 3);
    });

    test('BMEN-BK-011 | Vendor sends quote → proposalStatus = vendorQuoted', () async {
      await bookingRepo.vendorSendQuote(bookingId: proposalId, amount: 45000.0);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['proposalStatus'], 'vendorQuoted');
      expect(snap.data()!['vendorQuoteAmount'], 45000.0);
    });

    test('BMEN-BK-012 | User sends counter offer → proposalStatus = userCounter',
        () async {
      await bookingRepo.vendorSendQuote(bookingId: proposalId, amount: 45000.0);
      await bookingRepo.userCounterQuote(bookingId: proposalId, amount: 40000.0);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['proposalStatus'], 'userCounter');
      expect(snap.data()!['userCounterAmount'], 40000.0);
    });

    test('BMEN-BK-013 | User accepts vendor quote → booking status = accepted',
        () async {
      await bookingRepo.vendorSendQuote(bookingId: proposalId, amount: 45000.0);
      await bookingRepo.userAcceptQuote(bookingId: proposalId);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['status'], 'accepted');
      expect(snap.data()!['agreedAmount'], 45000.0);
    });

    test('BMEN-BK-014 | Vendor accepts user counter → booking status = accepted',
        () async {
      await bookingRepo.vendorSendQuote(bookingId: proposalId, amount: 45000.0);
      await bookingRepo.userCounterQuote(bookingId: proposalId, amount: 40000.0);
      await bookingRepo.vendorRespondToCounter(bookingId: proposalId, accept: true);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['status'], 'accepted');
      expect(snap.data()!['agreedAmount'], 40000.0);
    });

    test('BMEN-BK-015 | Vendor rejects counter → booking status = declined', () async {
      await bookingRepo.vendorSendQuote(bookingId: proposalId, amount: 45000.0);
      await bookingRepo.userCounterQuote(bookingId: proposalId, amount: 40000.0);
      await bookingRepo.vendorRespondToCounter(bookingId: proposalId, accept: false);
      final snap = await firestore.collection('bookings').doc(proposalId).get();
      expect(snap.data()!['status'], 'declined');
      expect(snap.data()!['proposalStatus'], 'vendorDeclined');
    });
  });

  // ── Payment Fee Calculation ───────────────────────────────────────────────

  group('[BOOKING] Payment Fee Verification', () {
    test('BMEN-BK-016 | Fee breakdown for ₹10000 booking is correct', () {
      final breakdown = calculateFeeBreakdown(10000.0);
      expect(breakdown.commission, closeTo(1000.0, 0.01)); // 10%
      expect(breakdown.gst, closeTo(180.0, 0.01));          // 18% on commission
      expect(breakdown.pgFee, closeTo(200.0, 0.01));         // 2%
      expect(breakdown.totalWithFees, closeTo(11380.0, 0.01));
    });

    test('BMEN-BK-017 | Fee breakdown for ₹45000 catering quote is correct', () {
      final breakdown = calculateFeeBreakdown(45000.0);
      expect(breakdown.commission, closeTo(4500.0, 0.01));
      expect(breakdown.gst, closeTo(810.0, 0.01));
      expect(breakdown.pgFee, closeTo(900.0, 0.01));
      expect(breakdown.totalWithFees, closeTo(51210.0, 0.01));
    });

    test('BMEN-BK-018 | Commission rate is 10%', () {
      expect(kCommissionRate, 0.10);
    });

    test('BMEN-BK-019 | GST rate on commission is 18%', () {
      expect(kCommissionGstRate, 0.18);
    });

    test('BMEN-BK-020 | PG fee rate is 2%', () {
      expect(kPaymentGatewayRate, 0.02);
    });
  });

  // ── Rating ────────────────────────────────────────────────────────────────

  group('[BOOKING] Post-Booking Rating', () {
    test('BMEN-BK-021 | Submitting rating saves on booking and updates vendor',
        () async {
      await firestore.collection('vendors').doc('v-rate').set({
        'ratingTotal': 0.0,
        'ratingCount': 0,
        'ratingAverage': 0.0,
      });

      final date = DateTime(2026, 11, 20);
      final id = await bookingRepo.createBooking(
        userId: 'u1',
        userName: 'U1',
        userEmail: 'u1@e.com',
        vendorId: 'v-rate',
        vendorOwnerUid: 'o-rate',
        vendorName: 'Vendor Rate',
        vendorCategory: 'Decoration',
        pricePerHour: 1500.0,
        startTime: DateTime(date.year, date.month, date.day, 10, 0),
        endTime: DateTime(date.year, date.month, date.day, 12, 0),
        eventDate: date,
      );
      await bookingRepo.submitRating(
        bookingId: id,
        rating: 5,
        review: 'Absolutely amazing!',
      );

      final bookingSnap = await firestore.collection('bookings').doc(id).get();
      expect(bookingSnap.data()!['rating'], 5);
      expect(bookingSnap.data()!['review'], 'Absolutely amazing!');

      final vendorSnap = await firestore.collection('vendors').doc('v-rate').get();
      expect(vendorSnap.data()!['ratingAverage'], closeTo(5.0, 0.01));
      expect(vendorSnap.data()!['ratingCount'], 1);
    });

    test('BMEN-BK-022 | Rating average updates correctly with multiple ratings',
        () async {
      await firestore.collection('vendors').doc('v-multi-rate').set({
        'ratingTotal': 0.0,
        'ratingCount': 0,
        'ratingAverage': 0.0,
      });

      final date1 = DateTime(2026, 11, 21);
      final date2 = DateTime(2026, 11, 22);

      final id1 = await bookingRepo.createBooking(
        userId: 'u1', userName: 'U1', userEmail: 'u1@e.com',
        vendorId: 'v-multi-rate', vendorOwnerUid: 'o-multi',
        vendorName: 'Multi Rate', vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(date1.year, date1.month, date1.day, 10, 0),
        endTime: DateTime(date1.year, date1.month, date1.day, 12, 0),
        eventDate: date1,
      );
      final id2 = await bookingRepo.createBooking(
        userId: 'u2', userName: 'U2', userEmail: 'u2@e.com',
        vendorId: 'v-multi-rate', vendorOwnerUid: 'o-multi',
        vendorName: 'Multi Rate', vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(date2.year, date2.month, date2.day, 10, 0),
        endTime: DateTime(date2.year, date2.month, date2.day, 12, 0),
        eventDate: date2,
      );

      await bookingRepo.submitRating(bookingId: id1, rating: 4);
      await bookingRepo.submitRating(bookingId: id2, rating: 2);

      final vendorSnap =
          await firestore.collection('vendors').doc('v-multi-rate').get();
      // Average of 4 and 2 = 3.0
      expect(vendorSnap.data()!['ratingAverage'], closeTo(3.0, 0.01));
      expect(vendorSnap.data()!['ratingCount'], 2);
    });
  });
}
